#!/usr/bin/env bash

set -eux

function build_qpdf()
{
	local -r image_tag="qpdf:${1}"
	docker build --tag "${image_tag}" --file qpdf.dockerfile --progress plain .
	image_id=$(docker create "${image_tag}")
	docker cp "${image_id}":/usr/src/qpdf/ .
}

function build_ghostscript()
{
	local -r image_tag="ghostscript:${1}"
	docker build --tag "${image_tag}" --file ghostscript.dockerfile --progress plain .
	image_id=$(docker create "${image_tag}")
	docker cp "${image_id}":/usr/src/ghostscript/ .
}

function build_jbig2enc()
{
	local -r image_tag="jbig2enc:${1}"
	docker build --tag "${image_tag}" --file jbig2enc.dockerfile --progress plain .
	image_id=$(docker create "${image_tag}")
	docker cp "${image_id}":/usr/src/jbig2enc/ .
}

case ${1} in

	qpdf)
		build_qpdf "${2}"
		;;

	ghostscript)
		build_ghostscript "${2}"
		;;

	jbig2enc)
		build_jbig2enc "${2}"
		;;

	*)
		echo "${1} is not a valid argument"
		exit 1
		;;
esac
