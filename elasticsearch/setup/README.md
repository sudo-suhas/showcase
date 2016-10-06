# Elasticsearch Setup
Production setup of elasticsearch which already has java 8 installed.

Following are the instructions for setting up a 3 node elasticsearch machine with 2 4gb machines
and 1 8gb machine which should run kibana and elasticsearch.
- Download and install the Public Signing Key:
    ```
    wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

    ```
- Save the repository definition to /etc/apt/sources.list.d/elasticsearch-2.x.list:
    ```
    echo "deb http://packages.elastic.co/elasticsearch/2.x/debian stable main" | sudo tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list

    ```
- Run apt-get update and the repository is ready for use. You can install it with:
    ```
    sudo apt-get update && sudo apt-get install elasticsearch

    ```
- The init script is placed at `/etc/init.d/elasticsearch`, and the configuration file is placed at `/etc/default/elasticsearch`
- File locations:
    - Elasticsearch home directory - `/usr/share/elasticsearch`
    - Configuration directory - `/etc/elasticsearch`
    - Data directory - `/var/lib/elasticsearch`
    - Log directory - `/var/log/elasticsearch`
- Update the following properties in the configuration files:
    - `/etc/default/elasticsearch`
        - `ES_HEAP_SIZE` - Set `ES_HEAP_SIZE` to 50% of available RAM
        - `MAX_OPEN_FILES=65535`
        - `MAX_LOCKED_MEMORY=unlimited`
        - `MAX_MAP_COUNT=262144`
    - `/etc/security/limits.conf` add the following:
        - `elasticsearch - nofile 65536`
        - `elasticsearch - memlock unlimited`
    - `/etc/sysctl.conf` - add `vm.max_map_count=262144`
    - If the data for elasticsearch is stored on a SSD hard disk, then change the scheduler to noop.
        `cat /sys/block/xvdb/queue/scheduler` will print the current scheduler(in square brackets).
        If the file system name is xvdb(ascertain using `df -f`), then run `sudo echo noop > /sys/block/xvdb/queue/scheduler`
    - Copy [elasticsearch.yml](elasticsearch.yml) from the repository to `/etc/elasticsearch` and edit the following properties:
        - `node.name: secret-node-1` - Change the sl.no as required. 8GB machine should be no.1
        - `discovery.zen.ping.unicast.hosts: ["host1", "host2"]` - Populate the host1 and host2 appropriately
- Start the elasticsearch service with the following commands:
    ```
    sudo update-rc.d elasticsearch defaults 95 10
    sudo /etc/init.d/elasticsearch start

    ```
    You can view the logs at `/var/log/elasticsearch/secret-application-prod.log`
- To restart the service `sudo service elasticsearch restart`

***

#### *Kibana*
- Download and install the Public Signing Key:
    ```
    wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
    ```
- Add the repository definition to your /etc/apt/sources.list.d/kibana.list file:
    ```
    echo "deb http://packages.elastic.co/kibana/4.5/debian stable main" | sudo tee -a /etc/apt/sources.list

    ```
- Run apt-get update and the repository is ready for use. Install Kibana with the following command:
    ```
    sudo apt-get update && sudo apt-get install kibana
    ```
- Config changes
    - Open `/opt/kibana/config/kibana.yml` for editing
        and set the `elasticsearch.url` to point at your Elasticsearch instance.
        Example:
        ```yaml
        elasticsearch.url: "http://localhost:9200"

        ```
- Configure Kibana to automatically start during bootup.
    ```
    sudo update-rc.d kibana defaults 96 9
    sudo service kibana start

    ```

***

#### *Sense*

You can install Sense by running the following command.
```
sudo /opt/kibana/bin/kibana plugin --install elastic/sense
```
Access sense here: http://localhost:5601/app/sense

***