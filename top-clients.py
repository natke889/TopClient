#import paramiko
#ssh_client =paramiko.SSHClient()
#ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
#ssh_client.connect(hostname='192.168.65.100',username='admin',password='Netapp1!')
#
#
#
#stdin,stdout,stderr=ssh_client.exec_command("statistics start -object top_client -sample-id sample_111 -sort-key total_ops")
##print (stdin)
#
#outlines=stdout.readlines()
#print(outlines[2])
#
#


####### Use paramiko to connect to LINUX platform############
#import paramiko
#
#ip='192.168.65.100'
#port=22
#username='admin'
#password='Netapp1!'
#ssh=paramiko.SSHClient()
#ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
#ssh.connect(ip,port,username,password)
#
#--------Connection Established-----------------------------

######To run shell commands on remote connection###########
import paramiko
import time

#ip='192.168.65.100'
#port=22
#username='admin'
#password='Netapp1!'
#ssh=paramiko.SSHClient()
#ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
#ssh.connect(ip,port,username,password)
#
#
#stdin,stdout,stderr=ssh.exec_command("set d; statistics start -object top_client -sample-id sample_111 -sort-key total_ops")
#outlines=stdout.readlines()
#resp=''.join(outlines)
#print(resp) # Output 
#ssh.close()

def ssh_command(command):
    """
    Graphite expects a byte array, in the format:
    'COUNTER_PATH VALUE TIMESTAMP\n'

    Counter path is a dot-seperated value, starting with graphite_root
    (e.g. 'netapp.perf.GROUP.mycluster.mynode-01') and ending with the 
    counter name (e.g. 'avg_latency').

    Make sure to adapt the variables of the counter path and consequently
    the arguments of this method!
    """
    ip='192.168.65.100'
    port=22
    username='admin'
    password='Netapp1!'
    ssh=paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip,port,username,password)
    
    stdin,stdout,stderr=ssh.exec_command(command)
    outlines=stdout.readlines()
    ssh.close()
    return outlines

def get_sample_status(command):
    output = ssh_command(command)
    output = (output[5]).rstrip()
    status = output.split()
    return (status[2])

def get_sample_records(command):
    
    records_data = []
    
    output = ssh_command(command_show)
    for i in output:
        if ('cifs' in i) or ('nfs' in i):
            records = i.split()
            records_data.append(dict({'protocol': records[1], 'svm': records[3], 'client': records[0], 'iops': records[2]}))
            
    return records_data


command_start = "set d; statistics start -object top_client -sample-id sample_111 -sort-key total_ops"
command_stop = "set d; statistics stop  -sample-id sample_111"
command_status = "set d; statistics samples show -sample-id sample_111 -fields sample-status"
command_show = "set d; statistics show -sample-id sample_111 -tab -counter total_ops|vserver_name|protocol -sort-key total_ops"
command_delete = "set d; statistics samples delete -sample-id sample_111"

try:
    ssh_command(command_start)
    time.sleep(10)
    ssh_command(command_stop)
    status = get_sample_status(command_status)
    
    while (status == 'Processing'):
        time.sleep(1)
        status = get_sample_status(command_status)        

    if (status == 'Ready'):
       collected_data = get_sample_records(command_show)
       print (collected_data)
        
        
    
    
    time.sleep(60)
finally:
    ssh_command("set d; statistics samples delete -sample-id sample_111")
    

   
   
   
   
   
   
   
   
   
   
   
   





#resp=''.join(outlines)

#print(type(resp)) # Output 
#host = "test.rebex.net"

#port = 22

#username = "demo"

#password = "password"


#command = "ls"


#ssh = paramiko.SSHClient()

#ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

#ssh.connect(host, port, username, password)


#stdin, stdout, stderr = ssh.exec_command(command)

#lines = stdout.readlines()

#print(lines)