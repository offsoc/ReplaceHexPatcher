# Replace Hex нативный для Windows

Language: Русский | [English](README.md)

- [Replace Hex нативный для Windows](#replace-hex-нативный-для-windows)
  - [Что это за репозиторий](#что-это-за-репозиторий)
  - [Альтернативы](#альтернативы)
  - [Функции](#функции)
  - [Примеры использования](#примеры-использования)
    - [Основной скрипт-патчер](#основной-скрипт-патчер)
    - [Скрипт-обертка с обработкой данных из template.txt](#скрипт-обертка-с-обработкой-данных-из-templatetxt)
  - [Что дает нативность](#что-дает-нативность)
  - [С чего начать](#с-чего-начать)
  - [Документация](#документация)
  - [ToDo](#todo)
  - [Список изменений](#список-изменений)
  - [Дополнительная информация](#дополнительная-информация)
  - [Системные требования](#системные-требования)
    - [Настройка Powershell](#настройка-powershell)
    - [Поддержка ОС](#поддержка-ос)


## Что это за репозиторий

Код в этом репозитории это результат попытки найти нативный для Windows способ для поиска и замены байт.

Нативный - значит он без использования сторонних программ (только средствами идущими в комплекте с системой, в данном случае Windows 10).

В UNIX-системах поиск и замену байт в hex формате можно осуществить с помощью утилит `perl` и `sed` (и, наверное, каких-то еще инструментов) которые предустановлены в большинство GNU Linux дистрибутивов и в macOS тоже.

В Windows предустановлены 4 "интерпретатора кода" - CMD, Visual Basic Script, Powershell, JavaScript.
CMD слишком ограничен в возможностях. В Visual Basic Script я не нашел способа написать эффективный код для поиска и замены шаблона байт в файле любого объема. А вот Powershell это, очень грубо говоря, среда выполнения кода C#, а с помощью C# можно делать очень многие вещи и поэтому с помощью кода на Powershell вполне можно выполнить поиск и замену байт в hex формате.

## Альтернативы

Я не нашел других готовых к использованию скриптов на Powershell или Visual Basic Script для поиска замены байт.
В данном случае альтернативный вариант - не нативный способ:

- sed можно скачать в (и входит в состав):
    - [sed-windows](https://github.com/mbuilov/sed-windows)
    - [sed for Windows](https://gnuwin32.sourceforge.net/packages/sed.htm) (GNU for Win32) + [Sourceforge files](https://sourceforge.net/projects/gnuwin32/files/sed/)
    - [Git for Windows](https://git-scm.com/download/win) или [сайт 2](https://gitforwindows.org/) и использовать `perl` и `sed` которые есть в Git Bash
    - [Cygwin](https://cygwin.com/)
    - [msysgit](https://github.com/msysgit/msysgit/) или [msys2](https://www.msys2.org/)
    - [GNU utilities for Win32](https://unxutils.sourceforge.net/)
    - [sed by Eric Pement](https://www.pement.org/sed/)
- [HexAndReplace](https://github.com/jjxtra/HexAndReplace)
- [BinaryFilePatcher](https://github.com/Invertex/BinaryFilePatcher)
- [BBE for Windows](https://anilech.blogspot.com/2016/09/binary-block-editor-bbe-for-windows.html)
- [HexPatcher](https://github.com/Haapavuo/HexPatcher/)

## Функции

Основная:
- Поиск и замена всех найденных последовательностей hex-байт
- Только поиск (подсчет вхождений) последовательностей hex-байт
- Вывод массива найденных позиций для каждого паттерна поиска в десятичном или шестнадцатеричном форматах
- Возможность использования подстановочных символов "??" в паттернах
- Создание бэкапов файлов в случае нахождения hex-паттернов
- Не строгий формат hex-значений (всеядность данных)
- Независимая длина паттернов замены
- Запрашивает права администратора только если это необходимо

Вместе с обертками:
- Замена байт в нескольких файлах или проверка, что они уже пропатчены
- Удаление файлов и папок
- Добавление строк в файл `hosts`
- Удаление конкретного текста и адресов из файла `hosts`
- Блокировка файлов в Windows Firewall
- Удаление всех правил для конкретных файлов из Windows Firewall
- Работа с файлом-шаблоном с заготовленными паттернами
  - Использование переменных в шаблоне
  - Создание новых текстовых файлов на основе текста
  - Создание новых файлов на основе base64
  - Применение строк для модификации реестра
  - Выполнение кода Powershell из шаблона
  - Выполнение кода CMD из шаблона

Больше информации смотрите в [документации](./docs/docs_RU.md)

## Примеры использования

### Основной скрипт-патчер

```powershell
.\ReplaceHexBytesAll.ps1 -filePath "<путь к файлу>" -patterns "<hex-паттерн поиска>/<hex-паттерн замены>",
```
- `hex-паттерн` не имеет строгого формата.
  - Между значениями в паттерне может быть любое количество пробелов и символов `\x` - все они удалятся (их наличие не вызовет ошибок)
  - В паттернах поиска и замены могут использоваться подстановочные знаки `??`
- разделитель между паттернами поиска и замены может быть одним из символов `/`,`\`,`|`
- в параметр `-patterns` можно передать как массив паттернов в виде строк разделенных запятой, так и 1 строку в которой наборы паттернов разделены запятой
- можно передать параметр `-makeBackup` и тогда оригинальный файл будет сохранен с добавленным расширением `.bak`

Вот пример:

1. Запустить Powershell
2. С помощью `cd <путь>` перейти в папку с файлом `ReplaceHexBytesAll.ps1`
3. В окне Powershell выполнить:
```powershell
.\ReplaceHexBytesAll.ps1 -filePath "D:\TEMP\file.exe" -patterns "48 83EC2 8BA2F 000000 488A/202 0EB1 1111 11111 111111","C425??488D4D68\90909011111175","45A8488D55A8|75EB88909090","\xAA\x7F\xBB\x08\xE3\x4D|\xBB\x90\xB1\xE8\x99\x4D","??1FBA0E??????CD21B8014CCD21????/????????????????74C3????????????" -makeBackup -showMoreInfo -showFoundOffsetsInHex
```

### Скрипт-обертка с обработкой данных из template.txt

В папке `wrappers` находится папка `data in template` и в ней файлы `Start.cmd`, `Parser.ps1`, `template.txt`

Примерный алгоритм:
1. Заполнить `template.txt` или любой другой txt-файл, в зависимости от того, что вам необходимо сделать
2. Запустить `Start.cmd` и выбрать написанный txt-файл
3. Либо через Powershell напрямую запустить `Parser.ps1` и передать ему путь или ссылку на шаблон в качестве аргумента:
```powershell
.\Parser.ps1 -templatePath "D:\путь к\template.txt"
```


## Что дает нативность

При реализации идеи упор был также на то, чтобы инструмент был полностью, абсолютно нативный для системы в которой он выполняется (то есть для Windows в данном случае). Чтобы не пришлось скачивать и устанавливать какие-то зависимости, библиотеки, runtime и прочее. Чтобы все выполнялось исключительно силами самой системы, то есть тем, что в ней есть "из коробки".

Ни одного бинарного файла в проекте нет ни в каком виде и они не нужны для работы утилиты. Только текст-код.

За счет этого можно ничего не скачивать, а просто в окне Powershell уже выполнить такую команду, для применения hex-паттернов:
```powershell
irm "https://github.com/Drovosek01/ReplaceHexPatcher/raw/refs/heads/main/core/v2/ReplaceHexBytesAll.ps1" -OutFile $env:TEMP\t.ps1; & $env:TEMP\t.ps1 -filePath "C:\Program Files\Adobe\Adobe Photoshop 2025\DaVinci Remote Monitor.exe" -patterns "B9000000/11111111", "0F 31 89 C2 44 29 C0 41 89 D0 44 39 C8 41 89 C1/11", "EF C4 66 41 0F 6F 22 66/778899" -showMoreInfo -makeBackup -showFoundOffsetsInHex; ri $env:TEMP\t.ps1
```
или
```powershell
irm "https://github.com/Drovosek01/ReplaceHexPatcher/raw/refs/heads/main/wrappers/data%20in%20template/Parser.ps1" -OutFile $env:TEMP\t.ps1; & $env:TEMP\t.ps1 '[start-flags]
MAKE_BACKUPS
VERBOSE
[end-flags]


[start-patch_bin]
C:\Users\USERNAME_FIELD\Desktop\hextests\DaVinci Remote Monitor.exe
7B 58 5D D9 80 DF 5F D8 52 69 63 68 81 DF 5F D8
112233

FF FF EF BF
AA 11 BB 22


C:\Users\USERNAME_FIELD\Desktop\hextests\CorelCAD.21.2.1.3523 Win 64bit.rar
00 00 3F 73
CC CC CC CC
2B 77 4D CE E9 B1 6D 92 89 BD 3B C3 3F A4 98 CC
2B 77 4D CE E9 B1 6D 92 89 BD 3B C3 3F A4 98 33
[end-patch_bin]'; ri $env:TEMP\t.ps1
```


## С чего начать

1. Начните с ручного выполнения действий.
  - Данный инструмент автоматизирует то, что обычно делается вручную - поиск и замена байт в hex-редакторе, изменение файла hosts, добавление или удаление правил в фаерволе и т.д. Если вы не умеете делать это вручную, то не использование автоматизированных средств, наверное, плохая идея
2. Ознакомьтесь с [документацией](./docs/docs_RU.md)
3. Потренируйтесь использовать только основной скрипт [ReplaceHexBytesAll.ps1](./core/ReplaceHexBytesAll.ps1) на каком-нибудь бинарном файле
4. Определитесь с тем, что вам необходимо сделать/автоматизировать - только замена байт или что-то еще
5. Исправьте/перепишите [шаблон](./wrappers/data%20in%20template/template.txt) под ваши задачи и протестируйте выполнение вашего шаблона


## Документация

В отдельном [файле](./docs/docs_RU.md)


## ToDo

В отдельном [файле](./docs/todo_RU.md)


## Список изменений

В отдельном [файле](./docs/changelog_RU.md)


## Дополнительная информация

В отдельном [файле](./docs/additional_info_RU.md)


## Системные требования

### Настройка Powershell

Настройка политики запуска скриптов Powershell (Execution Policy) - [learn.microsoft.com v1](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1), [learn.microsoft.com v2](https://learn.microsoft.com/previous-versions/windows/powershell-scripting/hh847748(v=wps.640)), [StackOverflow (RU)](https://ru.stackoverflow.com/questions/935212/powershell-%d0%b2%d1%8b%d0%bf%d0%be%d0%bb%d0%bd%d0%b5%d0%bd%d0%b8%d0%b5-%d1%81%d1%86%d0%b5%d0%bd%d0%b0%d1%80%d0%b8%d0%b5%d0%b2-%d0%be%d1%82%d0%ba%d0%bb%d1%8e%d1%87%d0%b5%d0%bd%d0%be-%d0%b2-%d1%8d%d1%82%d0%be%d0%b9-%d1%81%d0%b8%d1%81%d1%82%d0%b5%d0%bc%d0%b5)

Запускаем Powershell от имени администратора и выполняем команду

Для разового использования скрипта
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

Для частого использования скрипта
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
```

### Поддержка ОС

Весь код был написан и протестирован в Windows 10 x64 22H2.
Ожидается что и в Windows 11 это также будет работать "из коробки".

Я не проверял совместимость кода и использованных функций Powershell с предыдущими версиями. Вероятно для их выполнения понадобится Powershell 5.1 который идет в комплекте с Windows 10.

Если вы работаете на Windows 7, 8, 8.1 то, вероятно, вам необходимо будет установить [Microsoft .NET Framework 4.8](https://support.microsoft.com/topic/microsoft-net-framework-4-8-offline-installer-for-windows-9d23f658-3b97-68ab-d013-aa3c3e7495e0) и [Powershell 5.1](https://www.microsoft.com/download/details.aspx/?id=54616) чтобы код из этого репозитория у вас работал.