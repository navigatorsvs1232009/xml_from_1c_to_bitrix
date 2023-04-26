#!/bin/bash
#
# bitrexchange - bitrix exchange
# Скрипт стандартного обмена 1C и Битрикс по стандарту CommerceML
# Инкрементальная выгрузка XML файлов каталога import и offers
#
#Для того, чтобы не передались пустые или битые файлы, для предотвращения порчи данных, при любой ошибке завершаем работу скрипта.
set -e
#приём перехода в текущую директорию, и одновременно сохранение полного текущего пути в переменную
cd $(dirname $0)
cdir=$(pwd)"/"
#Обычно, 1С выкладывает файлы в какую-то расшареную папку на сервере в сети, которую мы заранее примонтируем. Но это может быть и локальная директория для вас, которая расшарена вами в сети
remote_dir="/mnt/localwinserver_fs/import/webdata/"
#Имя файла zip, в который будут запакованы xml файлы. Вместо этого, можно использовать просто временное имя. Но такое жёстко заданное имя файла используется для сохранения копий ранее переданных файлов. Очень удобно: можно в любой момент посмотреть, в какой день появился какой-то товар и по какой цене и т.п.
zip_fname="catalogue.zip"
#Имена файлов, которые мы будем передавать. Эти файлы формирует 1С, обычно у них такие имена, но могут быть и другие! Нужно проверить это! Файлы перечисляются через пробел
xml_files="import0_1.xml offers0_1.xml"
#Почта администратора, на которую направляются сообщения об ошибках.
#
email1="admin@yourinternetshop.com";
email2="alert@yourinternetshop.com";
#Определяем текущее время:
ctime=$(date +%Y-%m-%d-%H%M)

headers="--header=\"User-Agent: 1C+Enterprise/8.2\" --header=\"Accept-Encoding: deflate\""
login="import"
password="yourpasswordonbitrix"
baseurl="http://yourinternetshop.com/bitrix/admin/1c_exchange.php"
#Мы логинимся с помощью аутентификации по HTTP протокол
ret_line=$( wget $headers --user=${login} --password=${password} --auth-no-challenge -O - -q "${baseurl}?type=sale&mode=checkauth" )
read -a ret_ar <<< $ret_line
#Если sussecc получен, сохраняем переменнную сессии и её значение для дальнейшего использования, если нет, выходим из скрипта.
if [ ${ret_ar[0]} != "success" ]; then echo "Login error\r\n"; exit -1; fi
sessvar=${ret_ar[1]}
sessid=${ret_ar[2]}
echo sessid=$sessid
#Второй запрос — Init. При получении этого запроса полностью очищается(!) директория /upload/1c_catalog/ Будьте внимательны, если вам нужны какие-то данные предыдущей загрузки.
ret=$(wget $headers --header="Cookie: ${sessvar}=${sessid}" -O - -q "${baseurl}?type=catalog&mode=init"); echo $ret
ret=$(wget $headers --post-file ${zip_fname} --header="Cookie: ${sessvar}=${sessid}" -O - -q "${baseurl}?type=catalog&mode=file&filename=import.zip"); echo $ret
#Далее, согласно протоколу обмена 1C-Битрикс, нужно посылать запросы с mode=file, до тех пор, пока не будет получена строка success.
for fname in $xml_files; do
st="progress"; while [ "$st" = "progress" ]; do ret=$(wget $headers --header="Cookie: ${sessvar}=${sessid}" -O - -q "${baseurl}?type=catalog&mode=import&filename=${fname}"); st=$( <<< "$ret" head -n1 | cut -c1-8); echo "$ret" | iconv -f cp1251 -t utf-8; done
done
