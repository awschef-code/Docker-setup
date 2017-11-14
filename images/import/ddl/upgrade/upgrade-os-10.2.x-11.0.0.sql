-- upgrade VMOperatingSystem with new OS types
-- get ids
SOURCE ./upgrade-os-utils.sql;

SELECT min(id) FROM VMOperatingSystem WHERE name = 'Linux' INTO @linux_id;

call Add_OS_to_VMOS(@linux_id,@linux_id,'Linux|RHEL6','RHEL 6',@rhel6_id);

call Add_OS_to_VMOS(@linux_id,@rhel6_id,'Linux|RHEL6|6.9','RHEL 6.9',@rhel69_id);
call Add_OS_to_VMOS(@linux_id,@rhel69_id,'Linux|RHEL6|6.9|x64','RHEL 6.9 x64',@tmp_id);

call Add_OS_to_VMOS(@linux_id,@linux_id,'Linux|RHEL7','RHEL 7',@rhel7_id);

call Add_OS_to_VMOS(@linux_id,@rhel7_id,'Linux|RHEL7|7.4','RHEL 7.4',@rhel74_id);
call Add_OS_to_VMOS(@linux_id,@rhel74_id,'Linux|RHEL7|7.4|x64','RHEL 7.4 x64',@tmp_id);

call Add_OS_to_VMOS(@linux_id,@rhel7_id,'Linux|RHEL7|7.5','RHEL 7.5',@rhel75_id);
call Add_OS_to_VMOS(@linux_id,@rhel75_id,'Linux|RHEL7|7.5|x64','RHEL 7.5 x64',@tmp_id);

call Add_OS_to_VMOS(@linux_id,@linux_id,'Linux|CentOS6','CentOS 6',@centos6_id);

call Add_OS_to_VMOS(@linux_id,@centos6_id,'Linux|CentOS6|6.9','CentOS 6.9',@centos69_id);
call Add_OS_to_VMOS(@linux_id,@centos69_id,'Linux|CentOS6|6.9|x64','CentOS 6.9 x64',@tmp_id);

call Add_OS_to_VMOS(@linux_id,@linux_id,'Linux|CentOS7','CentOS 7',@centos7_id);

call Add_OS_to_VMOS(@linux_id,@centos7_id,'Linux|CentOS7|7.4','CentOS 7.4',@centos74_id);
call Add_OS_to_VMOS(@linux_id,@centos74_id,'Linux|CentOS7|7.4|x64','CentOS 7.4 x64',@tmp_id);

call Add_OS_to_VMOS(@linux_id,@centos7_id,'Linux|CentOS7|7.5','CentOS 7.5',@centos75_id);
call Add_OS_to_VMOS(@linux_id,@centos75_id,'Linux|CentOS7|7.5|x64','CentOS 7.5 x64',@tmp_id);

call Add_OS_to_VMOS(@linux_id,@linux_id,'Linux|Ubuntu','Ubuntu',@ubun_id);

call Add_OS_to_VMOS(@linux_id,@ubun_id,'Linux|Ubuntu|16.04','Ubuntu 16.04',@ubun1604_id);
call Add_OS_to_VMOS(@linux_id,@ubun1604_id,'Linux|Ubuntu|16.04|x64','Ubuntu 16.04 x64',@tmp_id);

call Add_OS_to_VMOS(@linux_id,@ubun_id,'Linux|Ubuntu|18.04','Ubuntu 18.04',@ubun1804_id);
call Add_OS_to_VMOS(@linux_id,@ubun1804_id,'Linux|Ubuntu|18.04|x64','Ubuntu 18.04 x64',@tmp_id);

