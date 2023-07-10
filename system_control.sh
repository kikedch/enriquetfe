#!/bin/bash

hanasid=HET
hanauser=hetadm

abapsid=TFE
abapinstnumber=00
abapuser=tfeadm

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "usage: $0 startAbap|stopAbap|startJava|stopJava|startDAA|stopDAA|startall|stopall" >&2
    exit 1
fi

CheckHana() {

dbuser=hetadm
SID=TFE

maxtries=${3:-6}
wait=${4:-10}
tries=1
#Se comprueba si existe el usuario de la base de datos, y en caso contrario se devuelve que el usuario no existe
if ! id -u "$dbuser" >/dev/null 2>&1; then
    echo 'Usuario '$dbuser' no existe en el sistema'
    exit 1
fi

if su - $abapuser -c "/sapmnt/$SID/exe/uc/linuxx86_64/R3trans -d > /dev/null "  ; ((ret=$?)) ; then
	return 1
else
	return 0
fi

#Se comprueba si el usuario del sistema Abap puede conectarse a la base de datos


while su - $abapuser -c "/sapmnt/$SID/exe/uc/linuxx86_64/R3trans -d > /dev/null "  ; ((ret=$?)) ;do
   echo "Unable to connect to database (attempt $tries): retrying in $wait seconds" >&2
   (( tries++ ))
   if [[ $tries -le $maxtries ]]; then
      sleep $wait
   else
      echo "Unable to connect to database : aborting"
      exit 1
   fi
done
}

CheckAbap () {
maxtries=${1:-6}
wait=${2:-6}
tries=1
RC=`su - $abapuser -c "/sapmnt/$abapsid/exe/uc/linuxx86_64/sapcontrol -nr $abapinstnumber -function GetProcessList > /dev/null"; echo $?`;
if [ $RC == $3 ]; then
	if [[ $4 == "start" ]]; then
		echo "System is already up and running.";
		return 0;
	elif [[ $4 == "stop" ]]; then
		echo "System is already stopped.";
		return 0;
	fi
fi
if [[ $4 == "stop" ]]; then
	while [[ $RC != $3 ]] ;do
	#echo "RC -> $RC";
	RC=`su - $abapuser -c "/sapmnt/$abapsid/exe/uc/linuxx86_64/sapcontrol -nr $abapinstnumber -function GetProcessList > /dev/null"; echo $?`;
	echo "Checking system status: retrying in $wait seconds" >&2
	(( tries++ ))
	if [[ $tries -le $maxtries ]]; then
		sleep $wait
	else
		echo "Unable to connect to ABAP : aborting"
		exit 1
	fi
	done
	echo "System is stopped.";
elif [[ $4 == "start" ]]; then
	while [[ $RC != $3 ]] ;do
	#echo "RC -> $RC";
	RC=`su - $abapuser -c "/sapmnt/$abapsid/exe/uc/linuxx86_64/sapcontrol -nr $abapinstnumber -function GetProcessList > /dev/null"; echo $?`;
	echo "Checking system status: retrying in $wait seconds" >&2
	(( tries++ ))
	if [[ $tries -le $maxtries ]]; then
		sleep $wait
	else
		echo "Unable to connect to ABAP : aborting"
		exit 1
	fi
	done
	echo "System is up and running.";
fi
	
return 0;
}

{
startAbap() {
        echo 'Starting SAP ABAP..'
        if  CheckHana $abapsid; then
                su - $abapuser -c "/sapmnt/$abapsid/exe/uc/linuxx86_64/sapcontrol -nr $abapinstnumber -function StartSystem ALL";
                echo "Checking abap";
                CheckAbap 10 10 3 start;
                #su - $abapuser -c "/sapmnt/$abapsid/exe/uc/linuxx86_64/sapcontrol -nr $abapinstnumber -function StartWait 120 1";
                echo 'After Starting SAP ABAP..';
                echo `date`;
        else echo "Error : HANA DB not avaliable";
        fi
}

stopAbap() {
        echo 'Stopping SAP ABAP..'
        su -  $abapuser -c "/sapmnt/$abapsid/exe/uc/linuxx86_64/sapcontrol -nr $abapinstnumber -function StopSystem ALL"
        CheckAbap 10 10 4 stop;
        echo 'After Stopping SAP ABAP..'
        echo `date`
}

startHana() {
		if CheckHana $abapsid; then
			echo "HANA DB already running";
		else
			if [[ "$hanasid" == "###" ]] ; then echo "HANASID no configurado"; 
			else
				echo 'Starting SAP HANA..'
				su - $hanauser -c "HDB start";
				echo 'After Starting SAP HANA..';
				echo `date`;
			fi
        fi
}

stopHana() {
		if CheckHana $abapsid; then
			if [[ "$hanasid" == "###" ]] ; then echo "HANASID no configurado"; else
					echo 'Stopping SAP HANA..'
					su - $hanauser -c "HDB stop";
					echo 'After Stopping SAP HANA..'
					echo `date`
			fi;
		else
			echo "HANA DB already stopped";
		fi
}

startall(){
        startHana;
        startAbap;
}

stopall(){
        stopAbap;
        stopHana;
}


case "$1" in
    startAbap)    startAbap;;
    stopAbap)    stopAbap ;;
    startHana)  startHana;;
    stopHana)   stopHana;;
    startall)   startall;;
    stopall)    stopall;;
    *) echo "usage: $0 startAbap|stopAbap|startHana|stopHana|startall|stopall" >&2
       exit 1
       ;;
esac

exit 0;


} | tee -a /root/scripts/logs/sapcontrol.log 2>&1
