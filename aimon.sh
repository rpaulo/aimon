#!/bin/sh
#
# Copyright (c) 2008 Rui Paulo <rpaulo@me.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

## BEGIN CONFIGURATION BLOCK ##

TS=300				# Time interval for the query.
RRDFILE=`dirname $0`/aimon.rrd	# Where to store the RRD file.
RRDTOOL=/usr/local/bin/rrdtool	# Location of the rrdtool.
RRDGRAPH_COLORS="-c BACK#ffffff -c SHADEA#ffffff -c SHADEB#ffffff"
RRDGRAPH_SIZE="-w 600 -h 200"
PUBDIR=`dirname $0`/pub		# Public directory where the images are stored.

## END CONFIGURATION BLOCK  ##

database_create()
{
	if [ -f $RRDFILE ]; then
		echo -n RRDTool database already exists. Please delete the
		echo file first.
		exit 1
	fi
	
	$RRDTOOL create $RRDFILE -s $TS		\
		DS:temp0:GAUGE:600:-2000:2000	\
		DS:temp1:GAUGE:600:-2000:2000	\
		DS:fan0:GAUGE:600:0:7000	\
		DS:fan1:GAUGE:600:0:7000	\
		DS:volt0:GAUGE:600:0:3000	\
		DS:volt1:GAUGE:600:0:6000	\
		DS:volt2:GAUGE:600:0:11000	\
		DS:volt3:GAUGE:600:0:20000	\
		RRA:AVERAGE:0.5:1:1200 
}


sysctl_query()
{
	return `/sbin/sysctl -n dev.acpi_aiboost.0.$1`
}

database_update()
{
	local temp0 temp1 fan0 fan1 volt0 volt1 volt2 volt3
	
	# XXX: ugly
	sysctl_query "temp0"
	temp0=$?
	sysctl_query "temp1"
	temp1=$?
	sysctl_query "fan0"
	fan0=$?
	sysctl_query "fan1"
	fan1=$?
	sysctl_query "volt0"
	volt0=$?
	sysctl_query "volt1"
	volt1=$?
	sysctl_query "volt2"
	volt2=$?
	sysctl_query "volt3"
	volt3=$?

	$RRDTOOL update $RRDFILE \
		N:$temp0:$temp1:$fan0:$fan1:$volt0:$volt1:$volt2:$volt3
	
	graph "temperatures"
	graph "fans"
	graph "volts"
}


graph()
{
	case $1 in
		temperatures)
			$RRDTOOL graph $PUBDIR/temp.png -t "Temperatures"	\
				-v "Celsius" $RRDGRAPH_COLORS		\
				$RRDGRAPH_SIZE				\
				DEF:_temp0=$RRDFILE:temp0:AVERAGE	\
				DEF:_temp1=$RRDFILE:temp1:AVERAGE 	\
				CDEF:ctemp0=_temp0,10,/			\
				CDEF:ctemp1=_temp1,10,/			\
				VDEF:ctemp0avg=ctemp0,AVERAGE		\
				VDEF:ctemp0max=ctemp0,MAXIMUM		\
				VDEF:ctemp0min=ctemp0,MINIMUM		\
				VDEF:ctemp1avg=ctemp1,AVERAGE		\
				VDEF:ctemp1max=ctemp1,MAXIMUM		\
				VDEF:ctemp1min=ctemp1,MINIMUM		\
				TEXTALIGN:left				\
				COMMENT:"\n"				\
				COMMENT:"                 "		\
				COMMENT:"     Max"	     		\
				COMMENT:"     Min"			\
				COMMENT:"     Avg\n"			\
				LINE1:ctemp0\#0000ff:"CPU\t\t\t"	\
				GPRINT:ctemp0max:"%6.2lf C"		\
				GPRINT:ctemp0min:"%6.2lf C"		\
				GPRINT:ctemp0avg:"%6.2lf C"		\
				COMMENT:"\n"				\
				LINE1:ctemp1\#ff0000:"Motherboard\t"	\
				GPRINT:ctemp1max:"%6.2lf C"		\
				GPRINT:ctemp1min:"%6.2lf C"		\
				GPRINT:ctemp1avg:"%6.2lf C" > /dev/null
			;;
		fans)
			$RRDTOOL graph $PUBDIR/fans.png -t "Fans" -v "RPM"	\
				$RRDGRAPH_COLORS $RRDGRAPH_SIZE		\
				DEF:fan0=$RRDFILE:fan0:AVERAGE		\
				DEF:fan1=$RRDFILE:fan1:AVERAGE		\
				VDEF:fan0avg=fan0,AVERAGE		\
				VDEF:fan0max=fan0,MAXIMUM		\
				VDEF:fan0min=fan0,MINIMUM		\
				VDEF:fan1avg=fan1,AVERAGE		\
				VDEF:fan1max=fan1,MAXIMUM		\
				VDEF:fan1min=fan1,MINIMUM		\
				TEXTALIGN:left				\
				COMMENT:"\n"				\
				COMMENT:"                       "	\
				COMMENT:"       Max"	     		\
				COMMENT:"       Min"			\
				COMMENT:"       Avg\n"			\
				LINE1:fan0\#0000ff:"CPU Fan Speed\t\t"	\
				GPRINT:fan0max:"%6.0lf RPM"		\
				GPRINT:fan0min:"%6.0lf RPM"		\
				GPRINT:fan0avg:"%6.0lf RPM"		\
				COMMENT:"\n"				\
				LINE1:fan1\#ff0000:"Chassis Fan Speed\t"\
				GPRINT:fan1max:"%6.0lf RPM"		\
				GPRINT:fan1min:"%6.0lf RPM"		\
				GPRINT:fan1avg:"%6.0lf RPM" > /dev/null
			;;
		volts)
			$RRDTOOL graph $PUBDIR/volts.png -t "Voltages" -v "Volt"\
				$RRDGRAPH_COLORS $RRDGRAPH_SIZE		\
				DEF:_volt0=$RRDFILE:volt0:AVERAGE	\
				DEF:_volt1=$RRDFILE:volt1:AVERAGE	\
				DEF:_volt2=$RRDFILE:volt2:AVERAGE	\
				DEF:_volt3=$RRDFILE:volt3:AVERAGE	\
				CDEF:cvolt0=_volt0,1000,/		\
				CDEF:cvolt1=_volt1,1000,/		\
				CDEF:cvolt2=_volt2,1000,/		\
				CDEF:cvolt3=_volt3,1000,/		\
				VDEF:cvolt0avg=cvolt0,AVERAGE		\
				VDEF:cvolt0max=cvolt0,MAXIMUM		\
				VDEF:cvolt0min=cvolt0,MINIMUM		\
				VDEF:cvolt1avg=cvolt1,AVERAGE		\
				VDEF:cvolt1max=cvolt1,MAXIMUM		\
				VDEF:cvolt1min=cvolt1,MINIMUM		\
				VDEF:cvolt2avg=cvolt2,AVERAGE		\
				VDEF:cvolt2max=cvolt2,MAXIMUM		\
				VDEF:cvolt2min=cvolt2,MINIMUM		\
				VDEF:cvolt3avg=cvolt3,AVERAGE		\
				VDEF:cvolt3max=cvolt3,MAXIMUM		\
				VDEF:cvolt3min=cvolt3,MINIMUM		\
				TEXTALIGN:left				\
				COMMENT:"                 "		\
				COMMENT:"     Max"	     		\
				COMMENT:"     Min"			\
				COMMENT:"     Avg\n"			\
				LINE1:cvolt0\#0000ff:"Vcore Voltage\t"	\
				GPRINT:cvolt0max:"%6.2lf V"		\
				GPRINT:cvolt0min:"%6.2lf V"		\
				GPRINT:cvolt0avg:"%6.2lf V"		\
				COMMENT:"\n"				\
				LINE1:cvolt1\#ff0000:"+3.3 Voltage\t"	\
				GPRINT:cvolt1max:"%6.2lf V"		\
				GPRINT:cvolt1min:"%6.2lf V"		\
				GPRINT:cvolt1avg:"%6.2lf V"		\
				COMMENT:"\n"				\
				LINE1:cvolt2\#00ff00:"+5 Voltage\t"	\
				GPRINT:cvolt2max:"%6.2lf V"		\
				GPRINT:cvolt2min:"%6.2lf V"		\
				GPRINT:cvolt2avg:"%6.2lf V"		\
				COMMENT:"\n"				\
				LINE1:cvolt3\#100000:"+12 Voltage\t"	\
				GPRINT:cvolt3max:"%6.2lf V"		\
				GPRINT:cvolt3min:"%6.2lf V"		\
				GPRINT:cvolt3avg:"%6.2lf V" > /dev/null
			;;
	esac
}

case $1 in
	create)
		database_create
		;;
	update)
		database_update
		;;
	autoupdate)
		while :; do
			database_update
			sleep $TS
		done
		;;
	*)
		echo Invalid command line option.
		exit 1
		;;
esac
