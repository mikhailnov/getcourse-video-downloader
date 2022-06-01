#!/usr/bin/env bash
# Simple script to download videos from GetCourse.ru
# on Linux/*BSD
# Dependencies: bash, coreutils, curl

set -eu
set +f
set -o pipefail

if [ ! -f "$0" ]
then
	a0="$0"
else
	a0="bash $0"
fi

_echo_help(){
	echo "
Первым аргументом должна быть ссылка на плей-лист, найденная в исходном коде страницы сайта GetCourse.
Пример: <video id=\"vgc-player_html5_api\" data-master=\"нужная ссылка\" ... />.
Вторым аргументом должен быть путь к файлу для сохранения скачанного видео, рекомендуемое расширение — ts.
Пример: \"Как скачать видео с GetCourse.ts\"
Скопируйте ссылку и запустите скрипт, например, так:
$a0 \"эта_ссылка\" \"Как скачать видео с GetCourse.ts\"
"
}

tmpdir="$(umask 077 && mktemp -d)"
export TMPDIR="$tmpdir"
trap 'rm -fr "$tmpdir"' EXIT

if [ -z "${1:-}" ] || \
   [ -z "${2:-}" ] || \
   [ -n "${3:-}" ]
then
	_echo_help
	exit 1
fi
URL="$1"
result_file="$2"
touch "$result_file"

main_playlist="$(mktemp)"
curl -L --output "$main_playlist" "$URL"
# В плей-листе перечислены ссылки на плей-листы частей видео а разных разрешениях,
# последним идет самое большое разрешение, его и скачиваем
second_playlist="$(mktemp)"
curl -L --output "$second_playlist" "$(tail -n1 "$main_playlist")"

c=0
while read -r line
do
	if ! [[ "$line" =~ ^http ]]; then continue; fi
	curl -L --output "${tmpdir}/$(printf '%05d' "$c").ts" "$line"
	c=$((++c))
done < "$second_playlist"

cat "$tmpdir"/*.ts > "$result_file"
echo "Скачивание завершено. Результат здесь:
$result_file"