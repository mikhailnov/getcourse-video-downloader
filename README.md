# Скрипт для скачивания видео с GetCourse без перекодирования

Некоторые [инструкции в интернете](https://www.nibbl.ru/poleznye-sovety/kak-skachat-video-s-getkursa-getcourse.html) предлагают скачивать видео с GetCourse с помощью VLC, однако это требует перекодирования видео.

Этот скрипт скачивает видео-уроки с Геткурса без перекодирования. Работает на Linux, BSD, macOS и в др. UNIX-подобных окружениях.

Для работы необходимы `bash` и `curl`.

Сначала найдите ссылку на видео:

* Откройте страницу с видео в браузере Chromium / Google Chrome
* Нажмите правой правой кнопкой мыши на видео, выберите "Просмотреть код"
* В открывшемся коде найдите: `<video id="vgc-player_html5_api" data-master="ДЛИННАЯ_ССЫЛКА"`
* Скопируйте эту ссылку (ДЛИННАЯ_ССЫЛКА)

![title](data/2022-01-03_20-02.png)
![title](data/2022-01-03_20-03.png)


Откройте терминал и выполните команду скачивания этого скрипта:

`curl -L --output /tmp/getcourse-video-downloader.sh https://github.com/mikhailnov/getcourse-video-downloader/raw/master/getcourse-video-downloader.sh`

Затем запустите скрипт:

`bash /tmp/getcourse-video-downloader.sh "ДЛИННАЯ_ССЫЛКА" "Имя файла.ts"`

Первым аргументом идет ссылка, вторым — имя файла, куда сохранить скачанное, рекомендуемое расширение — ts.
