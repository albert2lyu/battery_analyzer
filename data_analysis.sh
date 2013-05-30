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

sed -e "/^$/d" -e "s/, /,/g" $filename > data.tmp

# get total test time (in sec)
total_time=`awk -F',' 'END{print $1}' data.tmp`

# if [ `awk -F',' 'END{print $3}' data.tmp` -ne 0 ]; then
# 	echo "$(($total_time+20)),3500,0" >> data.tmp
# fi
awk 'BEGIN{FS=",";OFS=","} END{if($3){print $1+20,3500,0}}' data.tmp >> data.tmp

awk -v power=$device_watt 'BEGIN{FS=",";OFS=",";OLD_TIME=$1;SUM=0} {$(NF+1)=$1-OLD_TIME;OLD_TIME=$1;$(NF+1)=power*1000*1000/$2;$(NF+1)=$(NF)*$(NF-1)/3600;SUM+=$NF;$(NF+1)=SUM;print $0}' data.tmp > data.tmp1
rm data.tmp&&mv data.tmp1 data.tmp

sum_mah=`awk 'BEGIN{FS=",";OFS=",";SUM=0} END{print $(NF)}' data.tmp`
# echo "Total capacity: $sum_mah"

awk -v capacity=$sum_mah 'BEGIN{FS=",";OFS=","} {$(NF+1)=100*(1-$(NF)/capacity);print $0}' data.tmp  > data.tmp1
rm data.tmp&&mv data.tmp1 data.tmp

awk 'BEGIN{FS=",";OFS=",";OLD_PERCENT=99} {if(NR==1){PREV_LINE=$0}else{if(int($(NF))==int(OLD_PERCENT)){print PREV_LINE,0;PREV_LINE=$0}else{print PREV_LINE,OLD_PERCENT+1;OLD_PERCENT=int($(NF));PREV_LINE=$0}}} END{print PREV_LINE,1}' data.tmp > data.tmp1
rm data.tmp&&mv data.tmp1 data.tmp

awk 'BEGIN{FS=",";OFS=",";print "{"} $NF!=0{print "{"$2, $NF"},"} END{print "}\n"}' data.tmp

