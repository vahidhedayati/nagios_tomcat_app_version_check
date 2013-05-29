#!/bin/bash

###########################
input=$1;
instance=$2;
appname=$3;
tversion=$4;
restype=$5
###########################

###########################
querymethod="ping";
###########################

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
	foundhosts=$foundhosts" "$server
      fi
}
#############################################################################################



#############################################################################################
function get_servers() {
	for names in $(echo $input); do
    		server=$(echo $names|sed 's:(:{:g; s:):}:g; s:|:,:g; s/^//;s/$//');
   		for times in $(echo $server|grep -o "\["); do server=$(echo $server|sed 's/\(.*\)\[\(.*\)-\(.*\)]\(.*\)/\1\{\2\.\.\3\}\4/g'); done
		brace_expansion=$server;
  		IF=$'\n';
    		for server in $(eval echo $brace_expansion); do
			check_method;
		done
	done
}
#############################################################################################
function connect_server() {
	if [ "$foundhosts" != "" ];then
		result_back=""; sendit=""; result_versions=""; VER_ARRAY=();
		for hostname in $(echo $foundhosts); do
			for instances in $(echo $instance); do
				iid=$(echo $instances|sed 's:(:{:g; s:):}:g; s:|:,:g; s/^//;s/$//')
   				for times in $(echo $iid|grep -o "\["); do iid=$(echo $iid|sed 's/\(.*\)\[\(.*\)-\(.*\)]\(.*\)/\1\{\2\.\.\3\}\4/g'); done
				brace_instance=$iid;
				for instanceid in $(eval echo $brace_instance); do
					sendit=$sendit" app=\$(cat /opt/tomcat$tversion/$instanceid/webapps/$appname/META-INF/MANIFEST.MF|grep Implementation-Version|awk '{print \$NF}'|tr -d '\r');
					if [ !  \"\$app\" == \"\" ]; then
					if [[ \$app =~ SNAPSHOT ]]; then
					app=\${app%-*}; 
					fi;
					fi;
					echo -n  $hostname\"_\"$instanceid:\$app\" \";";
					
  				done
			done
			appversions=$(ssh $hostname "$sendit");
			result_back=$(echo -n $appversions)
		done
		if [[ $restype =~ overall ]]; then
			for versions in $(echo $result_back); do
				vid=${versions##*:}
                       		VER_ARRAY+=("$vid");
			done
                fi
		ngtext=$(echo -n $result_back|tr ":" "=");
		gtext=$gtext" "$(echo -n $ngtext);
		if [[ $restype =~ overall ]]; then
                	asum=0; i=0; ares=""; agraphres=""; dotcount=0; goodres=""; badres=""; graphres=""; sorted_size=0; vids="";
                        SORTED_ARRAY=$(echo "${VER_ARRAY[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
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
#############################################################################################

#############################################################################################
if [ $# -eq 0 -o $# -lt 4 ]; then
	echo "$0 \"host\" \"port\" appname tomcat_version {overall}";
   	echo "$0 \"host1 host2\" \"tc[1-2]\" appname tomcat_version";
   	echo "$0 \"host1 host2\" \"tc[1-2]\" appname  6";
   	echo "$0 \"host[1-2]\" \"tc[1-2]\" appname  6";
   	echo "$0 \"host[1-2]\" \"tc[1-2]\" appname  6 overall";
    	exit 1;
fi
#############################################################################################

#############################################################################################
get_servers;
connect_server;
#############################################################################################
