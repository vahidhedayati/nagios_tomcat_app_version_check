nagios_tomcat_app_version_check
===============================

This script will get the overall application versions for a running tomcat application and then map them all together - alert when overall app version (clustered applications) differ 


    -> This will check all applications running on wildcard hosts of apache-{a-z}lon
    - So any hosts that match the above naming convention
    - set up on multi tomcat environment so looks for folder /var/log/tomcat/tomcat{1..4}
    - your_app after the [1-4] is the application folder name
    - 6 is the tomcat version - define this as per your tomcat folder path .. /var/log/tomcat{6}.. /var/log/tomcat{5}
    -  you may need to rewrite some of this to match your set up
    
    define service{
        use                             your_group,srv-pnp
        hostgroup_name                  appver-your_app
        ;servicegroups                  appver-your_app
        service_description             your_app App Versions
        check_command                   app_version!apache-[a-z]lon!tomcat[1-4]!your_app!6!
    }


    define service{
        use                             your_group,srv-pnp
        hostgroup_name                  appver-your_app
        ;servicegroups                  appver-your_app
        service_description             OVERALL_VERSION_OF_your_app App Versions
        check_command                   app_version!apache-[a-z]lon!tomcat[1-4]!your_app!6!overall!
    }


The above services call the same script, the first one will ssh through to the pattern matched hosts, ports and return the version numbers per instance of the cluster. The second check is very similar but it does the overall check of all the cluster with two methods of calculation, a unique array check as well as a sum of all the version numbers / instances  - first version number returned = 0. Anything else will alert. This script is very useful to keep a birdseye view of all the version numbers of a given application. To ensure their all the same as well as grahing when deployments take place.  

Add this to your command.cfg

    define command {
        command_name app_version
        command_line $USER1$/check_app_version.sh "$ARG1$" "$ARG2$" $ARG3$ $ARG4$ $ARG5$
    }   
    # Test the script out
    #./check_app_version.sh "apache-[a-z]lon" "tomcat[1-3]" your_app 5
