#! /bin/bash

# define the DUT's power to calculate the current comsumption.
# device_watt=1
device_watt=0.76
total_time=0

function usage() {
	echo -e "Usage:\n$0 filename"
}

if [ $# -eq 0 ]; then
	usage
	exit 1
fi

filename=$1
tempfile=`mktemp`

sed -e "/^$/d" -e "s/, /,/g" $filename > $tempfile

# get total test time (in sec)
total_time=`awk -F',' 'END{print $1}' $tempfile`

awk 'BEGIN{FS=",";OFS=","} END{if($3){print $1+20,3500,0}}' $tempfile >> $tempfile

awk -v power=$device_watt 'BEGIN{FS=",";OFS=",";OLD_TIME=$1;SUM=0} {$(NF+1)=$1-OLD_TIME;OLD_TIME=$1;$(NF+1)=power*1000*1000/$2;$(NF+1)=$(NF)*$(NF-1)/3600;SUM+=$NF;$(NF+1)=SUM;print $0}' $tempfile > data.tmp
mv -f data.tmp $tempfile

sum_mah=`awk 'BEGIN{FS=",";OFS=",";SUM=0} END{print $(NF)}' $tempfile`
# echo "Total capacity: $sum_mah"

awk -v capacity=$sum_mah 'BEGIN{FS=",";OFS=","} {$(NF+1)=100*(1-$(NF)/capacity);print $0}' $tempfile  > data.tmp
mv -f data.tmp $tempfile

awk 'BEGIN{FS=",";OFS=",";OLD_PERCENT=99;print "TIME_SEC,BATT_VOLT,BATT_CAP,ELAPSED_TIME,BATT_MA,BATT_MAH,CONSUMED,CAPACITY,FINAL_CAP";} {if(NR==1){PREV_LINE=$0}else{if(int($(NF))==int(OLD_PERCENT)){print PREV_LINE,0;PREV_LINE=$0}else{print PREV_LINE,OLD_PERCENT+1;OLD_PERCENT=int($(NF));PREV_LINE=$0}}} END{print PREV_LINE,1}' $tempfile > data.tmp
mv -f data.tmp data.csv
rm -f $tempfile data.tmp

awk 'BEGIN{FS=",";OFS=",";print "{"} NR>1&&$NF!=0{print "{"$2,$NF"},"} END{print "}\n"}' data.csv

