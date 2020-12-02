#!/usr/bin/env sh

cleanup() {
	{ kill $(cat /tmp/sapebook2pdf-surf-pid)
	rm /tmp/sapebook2pdf-surf-pid
	kill $(cat /tmp/sapebook2pdf-shiny-pid)
	rm /tmp/sapebook2pdf-shiny-pid; } 2>/dev/null
}

reload() {
	if echo "$@" | grep -q 'shiny'; then
		echo "reload shiny"
		kill $(cat /tmp/sapebook2pdf-shiny-pid)
		Rscript app.R &
		echo "$!" > /tmp/sapebook2pdf-shiny-pid
		sleep 1.0 # startup time
	fi

	if echo "$@" | grep -q 'surf'; then
		echo "reload surf"
		kill -HUP $(cat /tmp/sapebook2pdf-surf-pid)
	fi
}

start() {
	if echo "$@" | grep -q 'surf'; then
		echo "start surf"
		surf localhost:"$PORT" &
		echo "$!" > /tmp/sapebook2pdf-surf-pid
	fi

	if echo "$@" | grep -q 'shiny'; then
		echo "start shiny"
		Rscript app.R >/dev/null 2>&1 &
		echo "$!" > /tmp/sapebook2pdf-shiny-pid
	fi
}

trap cleanup INT

export PORT=5000
case "$1" in
watch)
	start surf shiny
	entr -pc "$0" reload <<-EOF
	app.R
	make.sh
	EOF
	;;
reload)
	reload surf shiny
	;;
esac
