#!/bin/bash

Uses the MANIFEST.MF and grabs app version from it


input=$1;
instance=$2;
appname=$3;
tversion=$4;
restype=$5


querymethod="ping";
############################################################

#############################################################################################
#SERVER CHECK METHODS
function check_method() {
      if [ "$querymethod" == "ping" ]; then
  	ping -c1 $server 2>&1|grep bytes|grep time > /dev/null
      elif [ "$querymethod" == "disabled" ]; then
		echo "succeeded" > /dev/null
      else
		nc -v -w 1 $server -z $portid 2>&1|grep succeeded > /dev/null
      fi
      if [ $? = 0 ]; then
	foundhosts=$foundhosts" "$server:$instanceid
        #echo " $server:$instanceid querymethod = $querymethod -- SUCCEEDED"
      fi
}
#############################################################################################





function get_servers() {
	for instances in $(echo $instance); do
	iid=$(echo $instances|sed 's:(:{:g; s:):}:g; s:|:,:g; s/^//;s/$//')
   	for times in $(echo $iid|grep -o "\["); do iid=$(echo $iid|sed 's/\(.*\)\[\(.*\)-\(.*\)]\(.*\)/\1\{\2\.\.\3\}\4/g'); done
		brace_instance=$iid;
		for instanceid in $(eval echo $brace_instance); do
			for names in $(echo $input); do
    				server=$(echo $names|sed 's:(:{:g; s:):}:g; s:|:,:g; s/^//;s/$//');
   				for times in $(echo $server|grep -o "\["); do server=$(echo $server|sed 's/\(.*\)\[\(.*\)-\(.*\)]\(.*\)/\1\{\2\.\.\3\}\4/g'); done
				brace_expansion=$server;
  				IF=$'\n';
    				for server in $(eval echo $brace_expansion); do
					check_method;
    				done
   			done
 		 done
	done
}



function connect_server() {
                if [ "$foundhosts" != "" ];then
			result_back="";
			VER_ARRAY=();
			for names in $(echo $foundhosts); do
				#echo "Connecting to $names";
				hostname=${names%%:*}
				i_id=${names##*:}
				appversion="";
				appversion=$(ssh $hostname "cat /opt/tomcat$tversion/$i_id/webapps/$appname/META-INF/MANIFEST.MF|grep Implementation-Version|awk '{print \$NF}'|tr -d '\r' ")
				if [ !  "$appversion" == "" ]; then
					if [[ $appversion =~ SNAPSHOT ]]; then
                                         	appversion=${appversion%-*}
                                       	fi
					gtext=$gtext" "$hostname"_"$i_id=$appversion";;;;0 ";

					if [[ $restype =~ overall ]]; then 
						#VER_ARRAY+=("$hostname:$i_id:$appversion");
						VER_ARRAY+=("$appversion");
					fi

				  	result_back=$result_back" "$appname:$hostname:$i_id:$appversion
					#echo "$appname:$hostname:$i_id:$appversion|$i_id=$appversion "
				fi
				
			done
			if [[ $restype =~ overall ]]; then
                                asum=0;
                                i=0;
                                ares="";
                                agraphres="";
                                dotcount=0;
                                goodres="";
                                badres="";
                                graphres="";
                                SORTED_ARRAY=$(echo "${VER_ARRAY[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
                                sorted_size=0;
                                vids="";
                                for ids in ${SORTED_ARRAY[@]}; do
                                        ((sorted_size++))
                                        vids=$vids" "$ids;
                                done
                                if [[ $sorted_size -ge 2 ]]; then
                                        badres=$badres" Found $sorted_size unique Version ids: $vids";
                                else
                                        goodres=$goodres" Found $sorted_size unique Version id: $vids"

                                fi
                                asize=${#VER_ARRAY[@]};
                                for element in ${VER_ARRAY[@]}; do
                                        ((i++))
                                        if [[ $i -le 1 ]];  then
                                                agraphres=$element;
                                                dots=$(echo $element|grep -o "\."|wc -l);
                                                if [[ $dots -ge 2 ]]; then
                                                        dotcount=1;
                                                        ares=$(echo $element|tr -d ".");
                                                else
                                                        ares=$element;
                                                fi
                                        fi
                                        if [[ $dotcount -ge 1 ]]; then
                                                aval=$(echo $element|tr -d ".");
                                        else
                                                aval=$element;
                                        fi
                                        asum=$(echo "scale=2; $asum + $aval"|bc)
                                done
                                osum=$(echo "scale=2; $asum/$asize"|bc)
                                # So now if overall sum devided by array size equals first elements value all is ok
                                difference=$(echo "scale=2; $osum - $ares"|bc);
                                #echo "--> $osum -- $ares -- $difference"
                                if [[ "$difference" ==  "0" ]]; then
                                        goodres=$goodres" $appname  (Overall sum: $asum) / (Elements: $asize) = (Avg: $osum) -- (Avg: $osum) - (First result: $ares) = ($difference)"
                                        graphres="$appname=$agraphres;;;;0 "
                                else
                                        badres=$badres"  $appname (Overall sum:  $asum) /(Elements: $asize) = (Avg: $osum) -- (Avg: $osum) - (First result $ares) = ($difference)"
                                        graphres="$appname=0;;;;0 "
                                fi
                                if [[ -n $goodres ]] && [[ ! -n $badres ]]; then
                                                echo "OK: "$goodres"|"$graphres;
                                                exit 0;
                                else
                                        if [[ -n $badres ]]; then
                                                if [[ -n $goodres ]]; then
                                                        echo "CRITICAL: "$badres","$goodres"|"$graphres
                                                else
                                                        echo "CRITICAL: "$badres"|"$graphres
                                                fi
                                                exit 2;
                                        fi
                                fi
                        else
                                if [[ -n $result_back ]]; then
                                        echo $result_back"|"$gtext
                                fi
                        fi



                else
			echo "No Hosts >$foundhosts< have been resolved using $0 \"$input\" \"$instance\" $appname $tversion "
                fi
}



if [ $# -eq 0 -o $# -lt 4 ]; then
   # tomcat folders = /var/log/tomcat{tomcat_version/{tomcat_folder}
   # Written for multi tomcat environment - you will need to ammend if you run one tomcat instance
   echo "$0 \"host\" \"tomcat_folders\" appname tomcat_version";
   echo "$0 \"host1 host2\" \"tomcat[1-2]\" your_app tomcat_ver";
   echo "$0 \"host1 host2\" \"tomcat[1-2]\" your_app  tomcat_ver";
   echo "$0 \"host[1-2]\" \"tomcat[1-2]\"";
   
    exit 1;
fi

get_servers;
connect_server;

