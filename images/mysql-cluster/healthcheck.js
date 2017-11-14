var mysql=require('mysql')

// input params replaced via sed
var nodes=[NODES]
var mysql_root_user="MYSQL_ROOT_USER"
var mysql_root_password="MYSQL_ROOT_PASSWORD"
var session = null

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
            // println("Health of " + nodeAddress + " is " + health);
            // println("Mode   of " + nodeAddress + " is " + mode);
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
    var cluster=null
    for(var n=0,len=nodes.length; n<len; n++)
    {
        try
        {
            var node = nodes[n];
            var nodeAddress = node + ":3306";
            //println("trying to get cluster using " + nodeAddress);
            session=mysql.getClassicSession(mysql_root_user + "@" + nodeAddress, mysql_root_password);
            dba.resetSession(session);
            cluster=dba.getCluster();
            if (isWritableNode(nodeAddress, cluster)) {
                println("getCluster(): Returning cluster using node " + nodeAddress);
                break;
            }
            else {
                println("getCluster(): Ignoring cluster using node " + nodeAddress + " because not R/W");
                if (session != null) {
                    session.close();
                    session = null;
                }
            }
        }
        catch(err)
        {
            // cluster not defined 
            println("Failed getting cluster using " + nodeAddress + ": " + err.message)
        }
        if (session != null) {
            session.close();
            session = null;
        }
    }
    return cluster;
}


var result = 0
var cluster = getCluster();
if(cluster == null) 
{
    result = 1
}

if (session != null) {
    session.close();
}

result
