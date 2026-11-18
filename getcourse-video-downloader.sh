#!/usr/bin/env bash
# Simple script to download videos from GetCourse.ru
# on Linux/*BSD
# Dependencies: bash, coreutils, curl, grep

set -eu
set +f
set -o pipefail

if [ ! -f "$0" ]
then
	a0="$0"
else
	a0="bash $0"
fi

# ---------------------------------------------------------------------------
# Настройки повторных попыток (можно переопределить через переменные окружения)
# Пример: MAX_RETRIES=20 RETRY_DELAY=5 bash script.sh "url" "file.ts"
# ---------------------------------------------------------------------------
MAX_RETRIES="${MAX_RETRIES:-10}"        # сколько раз пробовать скачать один файл
RETRY_DELAY="${RETRY_DELAY:-3}"         # начальная пауза между попытками, сек
MAX_RETRY_DELAY="${MAX_RETRY_DELAY:-60}" # максимальная пауза (экспоненциальный рост)
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-20}" # таймаут на установку соединения, сек
MAX_TIME="${MAX_TIME:-300}"             # максимальное время на один запрос, сек

_echo_help(){
	echo "
Первым аргументом должна быть ссылка на плей-лист, найденная в исходном коде страницы сайта GetCourse.
Пример: <video id=\"vgc-player_html5_api\" data-master=\"нужная ссылка\" ... />.
Вторым аргументом должен быть путь к файлу для сохранения скачанного видео, рекомендуемое расширение — ts.
Пример: \"Как скачать видео с GetCourse.ts\"
Скопируйте ссылку и запустите скрипт, например, так:
$a0 \"эта_ссылка\" \"Как скачать видео с GetCourse.ts\"
Инструкция с графическими иллюстрациями здесь: https://github.com/mikhailnov/getcourse-video-downloader
О проблемах в работе сообщайте сюда: https://github.com/mikhailnov/getcourse-video-downloader/issues

Повторные попытки настраиваются переменными окружения:
MAX_RETRIES (по умолчанию $MAX_RETRIES), RETRY_DELAY ($RETRY_DELAY), MAX_RETRY_DELAY ($MAX_RETRY_DELAY),
CONNECT_TIMEOUT ($CONNECT_TIMEOUT), MAX_TIME ($MAX_TIME).
"
}

# Человекочитаемое описание частых кодов ошибок curl
_curl_err_desc(){
	case "$1" in
		6)  echo "не удалось определить IP хоста (DNS)" ;;
		7)  echo "не удалось подключиться к серверу" ;;
		18) echo "файл получен не полностью" ;;
		22) echo "сервер вернул HTTP-ошибку (4xx/5xx)" ;;
		28) echo "превышен таймаут" ;;
		35) echo "ошибка SSL/TLS-рукопожатия" ;;
		52) echo "сервер ничего не ответил (empty reply)" ;;
		55) echo "ошибка отправки данных" ;;
		56) echo "ошибка получения данных (соединение сброшено)" ;;
		92) echo "ошибка потока HTTP/2" ;;
		*)  echo "см. 'man curl', раздел EXIT CODES" ;;
	esac
}

# Скачивание с повторными попытками.
# $1 — URL, $2 — файл для сохранения.
# Повторяет при ЛЮБОЙ ошибке curl (включая 52, 56, 18, 28 и т. д.),
# с экспоненциально растущей паузой. Пустой результат тоже считается ошибкой.
_download(){
	local url="$1" out="$2"
	local attempt=1 delay="$RETRY_DELAY" rc
	while :
	do
		rc=0
		curl -L --fail --silent --show-error \
			--connect-timeout "$CONNECT_TIMEOUT" \
			--max-time "$MAX_TIME" \
			--output "$out" "$url" || rc=$?
		if [ "$rc" -eq 0 ]; then
			if [ -s "$out" ]; then
				return 0
			fi
			rc=-1
			echo "Попытка $attempt/$MAX_RETRIES: получен пустой файл" >&2
		else
			echo "Попытка $attempt/$MAX_RETRIES: ошибка curl $rc — $(_curl_err_desc "$rc")" >&2
		fi
		rm -f "$out"
		if [ "$attempt" -ge "$MAX_RETRIES" ]; then
			echo "Не удалось скачать после $MAX_RETRIES попыток: $url" >&2
			return 1
		fi
		echo "Повтор через $delay сек..." >&2
		sleep "$delay"
		attempt=$((attempt + 1))
		delay=$((delay * 2))
		if [ "$delay" -gt "$MAX_RETRY_DELAY" ]; then
			delay="$MAX_RETRY_DELAY"
		fi
	done
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
if ! _download "$URL" "$main_playlist"; then
	echo "Не удалось скачать основной плей-лист. Проверьте ссылку (она могла устареть — обновите страницу и скопируйте заново)." >&2
	exit 1
fi
second_playlist="$(mktemp)"
# Бывает (я встречал) 2 варианта видео
# Может быть, можно проверять [[ "$URL" =~ .*".m3u8".* ]]
# *.bin то же самое, что *.ts
if grep -qE '^https?:\/\/.*\.(ts|bin)' "$main_playlist" 2>/dev/null
then
	# В плей-листе перечислены напрямую ссылки на фрагменты видео
	# (если запустили проигрывание, зашли в инструменты разработчика Chromium -> Network,
	# нашли файл m3u8 и скопировали ссылку на него)
	cp "$main_playlist" "$second_playlist"
else
	# В плей-листе перечислены ссылки на плей-листы частей видео а разных разрешениях,
	# последним идет самое большое разрешение, его и скачиваем
	tail="$(tail -n1 "$main_playlist" | tr -d '\r')"
	if ! [[ "$tail" =~ ^https?:// ]]; then
		echo "В содержимом заданной ссылки нет прямых ссылок на файлы *.bin (*.ts) (первый вариант),"
		echo "также последняя строка в ней не содержит ссылки на другой плей-лист (второй вариант)."
		echo "Либо указана неправильная ссылка, либо GetCourse изменил алгоритмы."
		echo "Если уверены, что дело в изменившихся алгоритмах GetCourse, опишите проблему здесь:"
		echo "https://github.com/mikhailnov/getcourse-video-downloader/issues (на русском)."
		exit 1
	fi
	if ! _download "$tail" "$second_playlist"; then
		echo "Не удалось скачать плей-лист с фрагментами видео." >&2
		exit 1
	fi
fi

total="$(grep -cE '^https?://' "$second_playlist" || true)"
if [ "${total:-0}" -eq 0 ]; then
	echo "В плей-листе не найдено ссылок на фрагменты видео." >&2
	exit 1
fi

c=0
while read -r line
do
	line="${line%$'\r'}"
	if ! [[ "$line" =~ ^http ]]; then continue; fi
	echo "Фрагмент $((c + 1))/$total"
	if ! _download "$line" "${tmpdir}/$(printf '%05d' "$c").ts"; then
		echo "Фрагмент $((c + 1)) не скачан, прерываю. Видео не сохранено." >&2
		exit 1
	fi
	c=$((c + 1))
done < "$second_playlist"

cat "$tmpdir"/*.ts > "$result_file"
echo "Скачивание завершено ($c фрагментов). Результат здесь:
$result_file"