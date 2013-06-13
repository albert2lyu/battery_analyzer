#! /bin/bash

# define the DUT's power to calculate the current comsumption.
current=200
total_time=0
sample_time=3600

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

tempfile=`mktemp`

sed -e "/^$/d" -e "s/, /,/g" $filename > $tempfile

rm -f result.m
touch result.m
chmod +x result.m

time_step=`awk -F',' 'BEGIN{START=$1} NR==2{print $1-START}' $tempfile`
line2del=$(($sample_time/$time_step))
echo "line2del=$line2del time_step=$time_step"

# make sure the last line is zero base.
awk -v delta_line=$line2del 'BEGIN{FS=",";OFS=","} NR%delta_line==1{print $0} END{if($3){print $1+20,3500,1}}' $tempfile > data.tmp
mv -f data.tmp $tempfile

# delete the wrong sample datas.
awk 'BEGIN{FS=",";OFS=",";} {if(NR==1){PREV1=$1;PREV2=$2;PREV3=$3}else{if($2 < PREV2){print PREV1,PREV2,PREV3};PREV1=$1;PREV2=$2;PREV3=$3}} END{print PREV1,PREV2,PREV3}' $tempfile > data.tmp
mv -f data.tmp $tempfile

# get total test time (in sec)
total_time=`awk -F',' 'END{print $1}' $tempfile`
delta_time=$(($total_time/100))
echo "delta_time=$delta_time"

echo "#!/usr/bin/octave -q" >> result.m
echo "xx=0:$total_time/100:$total_time;" >> result.m
awk 'BEGIN{FS=",";print "x=["} {printf "%d,", $1}END{print "];"}' $tempfile >> result.m
awk 'BEGIN{FS=",";print "y=["} {printf "%d,", $2}END{print "];"}' $tempfile >> result.m
echo "res=spline(x,y,xx);" >> result.m
echo "plot(x,y,xx,spline(x,y,xx));" >> result.m

echo 'printf ("%d\n", res);' >> result.m
# print out the result in C style.
./result.m|awk 'BEGIN{FS=",";OFS=",";i=100;print "{"} NR!=1{printf("{%4d,%3d},\n",$1,i--)} END{print "}"}'
rm -f $tempfile

# awk -v 'BEGIN{FS=",";OFS=",";} {print $0}' $tempfile > data.tmp
# mv -f data.tmp $tempfile

# # get total capacity
# sum_mah=`awk 'BEGIN{FS=",";OFS=",";SUM=0} END{print $(NF)}' $tempfile`
# echo "Total capacity: $sum_mah"

# # calc the capacity in percentage
# awk -v capacity=$sum_mah 'BEGIN{FS=",";OFS=","} {$(NF+1)=100*(1-$(NF)/capacity);print $0}' $tempfile  > data.tmp
# mv -f data.tmp $tempfile

# # recalculate capacity
# awk 'BEGIN{FS=",";OFS=",";OLD_PERCENT=99;print "TIME_SEC,BATT_VOLT,BATT_CAP,ELAPSED_TIME,BATT_MA,BATT_MAH,CONSUMED,CAPACITY,FINAL_CAP";} {if(NR==1){PREV_LINE=$0}else{if(int($(NF))==int(OLD_PERCENT)){print PREV_LINE,0;PREV_LINE=$0}else{print PREV_LINE,OLD_PERCENT+1;OLD_PERCENT=int($(NF));PREV_LINE=$0}}} END{print PREV_LINE,1}' $tempfile > data.tmp
# mv -f data.tmp data.csv
# rm -f $tempfile data.tmp

# # print out the result in C style.
# awk 'BEGIN{FS=",";OFS=",";print "{"} NR>1&&$NF!=0{print "{"$2,$NF"},"} END{print "{0   ,0},\n}\n"}' data.csv
