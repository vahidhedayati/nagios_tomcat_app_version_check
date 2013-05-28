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
        service_description             your_app App Versions
        check_command                   app_version!apache-[a-z]lon!tomcat[1-4]!your_app!6!
    }
