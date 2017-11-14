var mysql=require('mysql')

// input params replaced via sed
var nodes=[NODES]
var mysql_root_user="MYSQL_ROOT_USER"
var mysql_root_password="MYSQL_ROOT_PASSWORD"

function getCluster()
{
    var cluster=null;
    for(var n=0,len=nodes.length; n<len; n++)
    {
        var node = nodes[n];
        var session=mysql.getClassicSession(mysql_root_user + "@" + node + ":3306", mysql_root_password);
        var cluster=null;
        try
        {
            dba.resetSession(session);
            cluster=dba.getCluster();
            break;
        }
        catch(err)
        {
            // cluster not defined
        }
        session.close();
    }
    return cluster;
}


var cluster = getCluster();
if(cluster == null)
{
}
else
{
    var status=cluster.status();
    //println("Cluster status:", status);

    var health={}
    var topology = status.defaultReplicaSet.topology;
    for(var topo_node in topology)
    {
        health[topo_node] = topology[topo_node].status
        var mode = topology[topo_node].mode
        var address = topology[topo_node].address
        if (health[topo_node] == "ONLINE" && mode == "R/W" )
        {
            println(address);
        }
    }
}
