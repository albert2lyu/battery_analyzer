#!/system/bin/busybox sh
# Author:Zhiqiang.xu
# Date:2013.05.28

delay_time=20
result_dir=/data/batt_sample

LOG() {
	echo `date` $1
}

# Return if charger exists.
is_charger()
{
	local charger_online=1
	local usb_online=`cat /sys/class/power_supply/usb/online`
	local ac_online=`cat /sys/class/power_supply/ac/online`
	local unknown_online=`cat /sys/class/power_supply/unknown/online`

	if [ $usb_online -eq 1 -o $ac_online -eq 1 -o $unknown_online -eq 1 ]
	then
		charger_online=1
	else
		charger_online=0
	fi
	LOG "charger_online=$charger_online"
	return $charger_online
}

# Return if battery is full.
is_batt_full()
{
	local batt_full=0
	local batt_cap=`cat /sys/class/power_supply/battery/capacity`
	local batt_status=`cat /sys/class/power_supply/battery/status`
	local batt_voltage=`cat /sys/class/power_supply/battery/voltage_now`

	if [ $batt_cap -eq 100 -a $batt_status = "Full" -a $batt_voltage -gt 4150 ]
	then
		batt_full=1
	else
		batt_full=0
	fi
	LOG "batt_full=$batt_full batt_voltage=$batt_voltage"
	return $batt_full
}

wait_ins_charger()
{
	LOG "Waiting charger!"
	is_charger
	until [ $? -eq 1 ]; do
		sleep 5
		is_charger
	done
	sleep 16
	LOG "Charger inserted!"
}

wait_remove_charger()
{
	LOG "Waiting remove charger!"
	LOG "Before removing charger. Make sure the device is ready to sampling!"
	is_charger
	while [ $? -eq 1 ]
	do
		sleep 5
		is_charger
	done
	LOG "Charger removed!"
}

svc power stayon false
if [ ! -d $result_dir ]
then
	mkdir -p $result_dir
fi

is_batt_full
batt_full=$?
is_charger
charger_online=$?
ready_sample=0
until [  $batt_full = 1 -a $charger_online = 0 -o $ready_sample = 1 ]; do
	if [ $batt_full = 1 -a $charger_online = 1 ]; then
		wait_remove_charger
		ready_sample=1
		svc power stayon true
		echo 255 > /sys/class/leds/lcd-backlight/brightness
		#am start -n com.android.music/com.android.music.MediaPlaybackActivity -d /sdcard1/01.mp3
	elif [ $batt_full = 0 -a $charger_online = 0 ]; then
		wait_ins_charger
	elif [ $batt_full = 0 -a $charger_online = 1 ]; then
		sleep 5
	else
		break
	fi
	is_batt_full
	batt_full=$?
	is_charger
	charger_online=$?
done

LOG "Battery is full! Start to sampling."

start_time=`date +%s`
filename=$result_dir/voltage_sample_`date +%Y%m%d-%H%M%S`.txt
while [ 1 ]
do
	curr_time=`date +%s`
	curr_voltage=`cat /sys/class/power_supply/battery/voltage_now`
	curr_batt_cap=`cat /sys/class/power_supply/battery/capacity`
	echo -e "$(($curr_time-$start_time)), $curr_voltage, $curr_batt_cap" >> $filename
	sleep $delay_time
done

