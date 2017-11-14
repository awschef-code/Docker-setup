var mysql=require('mysql')

// input params replaced via sed
var nodes=[NODES]
var mysql_root_user="MYSQL_ROOT_USER"
var mysql_root_password="MYSQL_ROOT_PASSWORD"

var session = null;

println("Checking cluster status: " + (new Date()).toString());


function isWritableNode(nodeAddress, cluster)
{
    if (nodeAddress == null || cluster == null || cluster.status() == null) {
        return false;
    }

    var topology = cluster.status().defaultReplicaSet.topology;
    for(var topo_node in topology)
    {
        var health  = topology[topo_node].status
        var mode    = topology[topo_node].mode
        var address = topology[topo_node].address

        if (address == nodeAddress) {
            println("Health of " + nodeAddress + " is " + health);
            println("Mode   of " + nodeAddress + " is " + mode);
            if (health == "ONLINE" && mode == "R/W" ) {
                println(nodeAddress + " is writable and online");
                return true;
            }
            else {
                println(nodeAddress + " is not writable and online");
                return false;
            }
        }
    }
    return false;
}

function getCluster()
{
    var cluster=null;
    for(var n=0,len=nodes.length; n<len; n++)
    {
        var node = nodes[n];
        var nodeAddress = node + ":3306";
        session=mysql.getClassicSession(mysql_root_user + "@" + nodeAddress, mysql_root_password);
        var cluster=null;
        try
        {
            dba.resetSession(session);
            cluster=dba.getCluster();
            if (isWritableNode(nodeAddress, cluster)) {
                println("getCluster(): Returning cluster using node " + nodeAddress);
                break;
            }
            else {
                if (session != null) {
                    session.close();
                    session = null;
                }
                println("getCluster(): Ignoring cluster using node " + nodeAddress + " because not R/W");
            }
        }
        catch(err)
        {
            // cluster not defined
        }

        if (session != null) {
            session.close();
            session = null;
        }
    }
    return cluster;
}


var cluster = getCluster();
if(cluster == null)
{
    println("Creating cluster: " + nodes[0]);
    var session=mysql.getClassicSession(mysql_root_user + "@" + nodes[0] + ":3306", mysql_root_password);
    session.runSql('drop database if exists mysql_innodb_cluster_metadata');
    dba.resetSession(session);
    cluster=dba.createCluster('agility')
    for(var n=1,len=nodes.length; n<len; n++)
    {
        var node=nodes[n];
        println("Adding node: " + node + " to new cluster");
        cluster.addInstance(node + ":3306",{password: mysql_root_password} );
    }
    var status=cluster.status();
    println("New Cluster status:", status);
}
else
{
    var status=cluster.status();
    println("Existing Cluster status:", status);

    var health={}
    var topology = status.defaultReplicaSet.topology;
    for(var topo_node in topology)
    {
        health[topo_node] = topology[topo_node].status
        if (health[topo_node] == "OFFLINE")
        {
            // remove any nodes that are offline
            try {
                println("Removing offline node: " + topo_node);
                cluster.removeInstance(topo_node);
            } catch(err) {
                // new node will throw warnings as not a cluster member
            }
        } else if (health[topo_node] == "(MISSING)") {
           println("Removing missing node: " + topo_node);
           cluster.removeInstance(topo_node);
           health[topo_node] = null;
        }
    }
    println("Health:", health);

    var changes=0;
    for(var n=0,len=nodes.length; n<len; n++)
    {
        var node = nodes[n] + ":3306";
        if(health[node] == null)
        {
            println("Adding previously unknown node: " + node);
            cluster.addInstance(node ,{password: mysql_root_password} );
            changes++;
        }
        else if (health[node] == "UNREACHABLE" || health[node] == "(MISSING)")
        {
            println("Removing unreachable/missing node: " + node);
            try {
                cluster.removeInstance(node);
            } catch(err) {
                // new node will throw warnings as not a cluster member
            }
            println("Adding back unreachable/missing node: " + node);
            cluster.addInstance(node ,{password: mysql_root_password} );
            changes++;
        }
    }

    if(changes > 0)
    {
        println("Updated Cluster status:", cluster.status());
    }

    if (session != null) {
        session.close();
    }
}
