#! /bin/bash
# Author:Zhiqiang.xu
# Date:2013.06.28

total_line=0
total_time=0
sample_point=10

function usage() {
	echo -e "Usage:\n$0 filename"
}

if [ $# -eq 0 ]; then
	usage
	exit 1
fi

if [ "`which octave`" == "" ]; then
	echo "Please install octave firstly. Or this script cannot run."
	exit 1
fi

filename=$1

if [ "$filename" = "" ]
then
	usage
	exit 1
elif [ ! -e $filename ]
then
	echo "$filename not found!"
	exit 1
fi

# check if the soc table is correct.
function checkData() {
	# DEBUG
	# awk 'BEGIN{FS=",";OFS=",";i=100;} {if(NR==1){PREV1=$1}else{if($1 >= PREV1){printf("Error:%d%%,%d\n",i, $1);exit};PREV1=$1;i--}} END{print "Check Done!";exit i}' $1
	awk 'BEGIN{FS=",";OFS=",";i=100;} {if(NR==1){PREV1=$1}else{if($1 >= PREV1){exit};PREV1=$1;i--}} END{exit i}' $1
	return $?
}

tempfile=`mktemp`

# delete blank lines.
sed -e "/^$/d" -e "s/, /,/g" $filename > $tempfile

rm -f result.m
touch result.m
chmod +x result.m

# delete the wrong sample datas.
while [ 1 ]; do
    awk 'BEGIN{FS=",";OFS=",";} {if(NR==1){PREV1=$1;PREV2=$2;PREV3=$3}else{if($2 <= PREV2){print PREV1,PREV2,PREV3;}else{print "bad"};PREV1=$1;PREV2=$2;PREV3=$3}} END{print PREV1,PREV2,PREV3;if($3){print $1+20,3500,0}}' $tempfile > data.tmp
    cp -f data.tmp temp.log
    mv -f data.tmp $tempfile
    grep bad $tempfile > /dev/null||break
    sed -i "/bad/d" $tempfile
done

total_line=`wc -l < $tempfile`
center_line=$(($total_line/2))

while [ 1 ]; do
	echo $sample_point
	line2del=$(($center_line/$sample_point))
	echo "total_line=$total_line line2del=$line2del center_line=$center_line"

	awk -v delta_line=$line2del -v center=$center_line 'BEGIN{FS=",";OFS=","} NR%delta_line==1 || NR==center{print $0;if(NR==center){exit}}' $tempfile > data_tophalf.tmp

	awk -v delta_line=$line2del -v center=$center_line -v total=$total_line 'BEGIN{FS=",";OFS=","} NR==center || NR==total{print $0} NR>center && NR<total && NR%delta_line==1{print $0}' $tempfile > data_bottomhalf.tmp

# get total test time (in sec)
	total_time=`awk -F',' 'END{print $1}' $tempfile`

	echo "#!`which octave` -fq" > result.m
	echo "xx=0:$total_time/100:$total_time;" >> result.m
	awk 'BEGIN{FS=",";print "x=["} {printf("%d,", $1)}END{print "];"}' $tempfile >> result.m
	awk 'BEGIN{FS=",";print "y=["} {printf("%d,", $2)}END{print "];"}' $tempfile >> result.m
	echo "xx1=0:$total_time/100:$total_time/2;" >> result.m
	echo "xx2=$total_time/2+$total_time/100:$total_time/100:$total_time;" >> result.m
	awk 'BEGIN{FS=",";print "x1=["} {printf("%d,", $1)}END{print "];"}' data_tophalf.tmp >> result.m
	awk 'BEGIN{FS=",";print "y1=["} {printf("%d,", $2)}END{print "];"}' data_tophalf.tmp >> result.m
	echo "res1=spline(x1,y1,xx1);" >> result.m
	awk 'BEGIN{FS=",";print "x2=["} {printf("%d,", $1)}END{print "];"}' data_bottomhalf.tmp >> result.m
	awk 'BEGIN{FS=",";print "y2=["} {printf("%d,", $2)}END{print "];"}' data_bottomhalf.tmp >> result.m
	echo "res2=spline(x2,y2,xx2);" >> result.m
	echo 'printf ("%d\n", res1);' >> result.m
	echo 'printf ("%d\n", res2);' >> result.m
# print out the result in C style.
	./result.m > data.tmp
	checkData data.tmp

	if [ $? == 0 -o $sample_point -ge 100 ]; then
		break
	fi

	sample_point=$(($sample_point + 1))
done

awk 'BEGIN{FS=",";OFS=",";i=100;print "{"} NR!=1{printf("  {%4d,%3d},\n",$1,i--)} END{printf("  {%4d,%3d}\n}\n", 0, 0)}' data.tmp
if [ $sample_point -ge 100 ]; then echo "The result is not reliable. Something may be wrong. Please check the data and try again.";fi

# Draw the sample data and the result.
echo "plot(x,y,xx1,res1,xx2,res2);" >> result.m
echo "pause;" >> result.m
./result.m > /dev/null

# clean the temperal files.
rm -f $tempfile *.tmp result.m

