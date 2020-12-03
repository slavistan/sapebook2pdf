#!/usr/bin/env sh

_cleanup() {
	{ kill $(cat /tmp/sapebook2pdf-surf-pid)
	rm /tmp/sapebook2pdf-surf-pid
	kill $(cat /tmp/sapebook2pdf-shiny-pid)
	rm /tmp/sapebook2pdf-shiny-pid; } 2>/dev/null
}

_reload() {
	if echo "$@" | grep -q 'shiny'; then
		echo "reload shiny"
		kill $(cat /tmp/sapebook2pdf-shiny-pid)
		Rscript app.R &
		echo "$!" > /tmp/sapebook2pdf-shiny-pid
		sleep 2.0 # startup time
	fi

	if echo "$@" | grep -q 'surf'; then
		echo "reload surf"
		kill -HUP $(cat /tmp/sapebook2pdf-surf-pid)
	fi
}

_start() {
	if echo "$@" | grep -q 'shiny'; then
		echo "start shiny"
		Rscript app.R &
		echo "$!" > /tmp/sapebook2pdf-shiny-pid
		sleep 2.0
	fi

	if echo "$@" | grep -q 'surf'; then
		echo "start surf"
		surf "localhost:$PORT" &
		echo "$!" > /tmp/sapebook2pdf-surf-pid
	fi
}

trap _cleanup INT

export PORT=5000
case "$1" in
watch) # Hot reload during rev
	_start surf shiny
	entr -pc "$0" _reload <<-EOF
	app.R
	make.sh
	EOF
	;;
start)
	Rscript app.R
	;;
_reload)
	_reload surf shiny
	;;
@)
	shift
	"$@"
	;;
*)
	echo "Shiny server. Usage: $0 start"
	;;
esac
