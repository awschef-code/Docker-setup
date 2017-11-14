FROM dockerhub.servicemesh.com/agility/mysql-gr:5.7.18-1.8

ADD upgradeDB.sh upgradeDB.sh
ADD ddl/ ddl/

CMD ["tail","-f","/dev/null"]
