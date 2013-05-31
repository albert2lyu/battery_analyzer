#! /bin/bash

# define the DUT's power to calculate the current comsumption.
current=200
device_watt=0
total_time=0

function usage() {
	echo -e "Usage:\n$0 -i current -f filename"
}

if [ $# -eq 0 ]; then
	usage
	exit 1
fi
while getopts ":i:f:" opt; do
	case $opt in
		i)
			current=$OPTARG
			continue
			;;
		f)
			echo $OPTARG
			filename=$OPTARG
			continue
			;;
		\?|:)
			usage
			exit 1
			;;
	esac
done

if [ "$filename" = "" ]
then
	usage
	exit 1
elif [ ! -e $filename ]
then
	echo "$filename not found!"
	exit 1
fi

device_watt=`echo "scale=3;4*$current/1000"|bc`
tempfile=`mktemp`

sed -e "/^$/d" -e "s/, /,/g" $filename > $tempfile

# get total test time (in sec)
total_time=`awk -F',' 'END{print $1}' $tempfile`

# make sure the last line is zero base.
awk 'BEGIN{FS=",";OFS=","} END{if($3){print $1+20,3500,0}}' $tempfile >> $tempfile

# calc sample step time, current, capacity(mAh)/step, total capacity(mAh)
awk -v power=$device_watt 'BEGIN{FS=",";OFS=",";OLD_TIME=$1;SUM=0;PREV_CURR=0} {$(NF+1)=$1-OLD_TIME;OLD_TIME=$1;$(NF+1)=power*1000*1000/$2;$(NF+1)=($(NF)+PREV_CURR)/2*$(NF-1)/3600;PREV_CURR=$(NF-1);SUM+=$NF;$(NF+1)=SUM;print $0}' $tempfile > data.tmp
mv -f data.tmp $tempfile

# get total capacity
sum_mah=`awk 'BEGIN{FS=",";OFS=",";SUM=0} END{print $(NF)}' $tempfile`
echo "Total capacity: $sum_mah"

# calc the capacity in percentage
awk -v capacity=$sum_mah 'BEGIN{FS=",";OFS=","} {$(NF+1)=100*(1-$(NF)/capacity);print $0}' $tempfile  > data.tmp
mv -f data.tmp $tempfile

# recalculate capacity
awk 'BEGIN{FS=",";OFS=",";OLD_PERCENT=99;print "TIME_SEC,BATT_VOLT,BATT_CAP,ELAPSED_TIME,BATT_MA,BATT_MAH,CONSUMED,CAPACITY,FINAL_CAP";} {if(NR==1){PREV_LINE=$0}else{if(int($(NF))==int(OLD_PERCENT)){print PREV_LINE,0;PREV_LINE=$0}else{print PREV_LINE,OLD_PERCENT+1;OLD_PERCENT=int($(NF));PREV_LINE=$0}}} END{print PREV_LINE,1}' $tempfile > data.tmp
mv -f data.tmp data.csv
rm -f $tempfile data.tmp

# print out the result in C style.
awk 'BEGIN{FS=",";OFS=",";print "{"} NR>1&&$NF!=0{print "{"$2,$NF"},"} END{print "}\n"}' data.csv
