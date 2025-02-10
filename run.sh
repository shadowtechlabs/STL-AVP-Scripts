#!/bin/sh

#First - lets determine if AVP is running in a docker container, if we are, set up the export dir. 
if [ -f /.dockerenv ]; then
    # Identify the default network interface while ignoring loopbacks
    ip_addresses=$(hostname -I | tr ' ' '\n' | grep -vE '^127\.|^::1' | head -n 1)
    ip_address=$(echo "$ip_addresses" | head -n 1)

    #Create export directory for piping out hot steamy logs and alarms to docker volume
    mkdir -p /hunter/export/"$ip_address"/logs
    mkdir -p /hunter/export/"$ip_address"/Alarms
    EXPORTDIR=/hunter/export/"$ip_address"


    #Set logdir & alarmdir
    LOGDIR=/hunter/Software/logs
    ln -sfn "$EXPORTDIR"/logs /hunter/Software/logs
    ln -sfn "$EXPORTDIR"/Alarms ../Alarms
else
    LOGDIR=/hunter/Software/logs/
fi

# Get total RAM in KB and convert to GB
total_ram_gb=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)}')
# Set Java heap to 80% of total RAM
max_heap=$((total_ram_gb * 80 / 100))

STL_ARGS="-showroi Config/shadow15.xml"
if [ ! -z "$1" ]; then
    case "$1" in
        "-d")
            if ! grep -q "DEBUG" logback.xml; then
                sed -i 's/INFO/DEBUG/' logback.xml
                echo "logback set to DEBUG"
            elif grep -q "DEBUG" logback.xml; then
                echo "logback already set to DEBUG"
            else
                echo "error 1"
            fi
            shift
        ;;
        *)
                echo "ambiguous option $@. no changes made"
                shift
        ;;
    esac
else
    if grep -q "DEBUG" logback.xml; then
        sed -i 's/DEBUG/INFO/' logback.xml
        echo 'debug set to info'
    fi
fi
JMXPORT=9010
if [ ! -d ${LOGDIR} ]
then
   mkdir ${LOGDIR}
fi
JAVA_ARGS="-Dlogback.configurationFile=logback.xml -Dgnu.io.rxtx.SerialPorts=/dev/ttyACM0:/dev/ttyACM1:/dev/ttyACM2:/dev/ttyACM3:/dev/ttyACM4:/dev/ttyACM5:/dev/ttyACM6:/dev/ttyACM7:/dev/ttyACM8:/dev/ttyACM9:/dev/ttyS0:/dev/ttyS1:/dev/ttyUSB0 -Xms4g -Xmx${max_heap}g -XX:MaxGCPauseMillis=1000 -XX:NewRatio=1"

sleep 2
JAVA=jre/bin/java
${JAVA} ${JAVA_ARGS} -jar shadownet.jar ${STL_ARGS} >> ${LOGDIR}/shadownet.out 2>> ${LOGDIR}/shadownet.err
