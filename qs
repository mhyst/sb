#!/bin/bash
#################################################################################################
# V A R I A B L E S
#################################################################################################

SQLITE="sqlite3 /home/mhyst/bin/scripts/sb/sbdb"
#Nombre del script
CODENAME="qs"
#Current version
VERSION="0.0.1"

#################################################################################################
# Funciones reutilizables
#################################################################################################

function userChoice() {

	local limite=$1
	local cadena="$2"
	local reply
	let reply=0

	echo > /dev/tty
	echo "$cadena" > /dev/tty
	read reply < /dev/tty
	echo > /dev/tty

	#We see if the user entered a number such as we need
	while [[ "$reply" -lt 0 ]] || [[ "$reply" -gt  $limite ]]; do

		#We give advice to the user and exit
		echo "Tiene que introducir un número de entre los indicados:" > /dev/tty
		read reply < /dev/tty
		#echo "Reply es: $reply" > /dev/tty

	done

	echo $reply
}

trim() {
	local FOO="$1"
	FOO_NO_EXTERNAL_SPACE="$(echo -e "${FOO}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
	echo "$FOO_NO_EXTERNAL_SPACE"
}

##################################################################################################
# Funciones base de datos
#-------------------------------------------------------------------------------------------------
# Todas ellas contendrán query en su nombre
##################################################################################################

function querySeries() {
	local search="$1 $2 $3 $4 $5 $6 $7 $8 $9"

	search=$(trim $search)

	local res=`$SQLITE "select * from series where titulo like '%$search%' order by titulo"`
	echo "$res"
}

function queryTemporadas() {
	local idserie="$1"

	if $vervistos; then
		local res=`$SQLITE "select distinct(temporada) from episodios where idserie = $idserie"`
	else
		local res=`$SQLITE "select distinct(temporada) from episodios where idserie = $idserie and visto = 0"`
	fi

	echo "$res"
}

function queryEpisodios() {
	local idserie="$1"
	local ltemporada="$2"

	if $vervistos || (( $temporada > -1)); then
		local res=`$SQLITE "select * from episodios where idserie = $idserie and temporada = $ltemporada"`
	else
		local res=`$SQLITE "select * from episodios where idserie = $idserie and temporada = $ltemporada and visto = 0"`
	fi
	echo "$res"
}

function queryEpisodio() {
	local idserie="$1"
	local temporada="$2"
	local episodio="$3"

	#echo "SQL=select * from episodios where idserie = $idserie and temporada = $temporada and episodio = $episodio" > /dev/tty
	local res=`$SQLITE "select * from episodios where idserie = $idserie and temporada = $temporada and episodio = $episodio"`
	echo "$res"
}

function setVisto() {
	local idepisodio="$1"

	local res=`$SQLITE "update episodios set visto=visto+1 where id = $idepisodio"`
	echo "$res"	
}

function queryEnlaces() {
	local idserie="$1"
	local idepisodio="$2"

	local res=`$SQLITE "select * from enlaces where idserie = $idserie and idepisodio = $idepisodio"`
	echo "$res"
}

function queryEnlacesFiltro() {
	local idserie="$1"
	local idepisodio="$2"
	local servicio="$3"

	#echo "select * from enlaces where idserie = $idserie and idepisodio = $idepisodio and url like '%$servicio%'" > /dev/tty
	local res=`$SQLITE "select * from enlaces where idserie = $idserie and idepisodio = $idepisodio and url like '%$servicio%'"`
	echo "$res"
}

#ATENCION!!!
#Las funciones back, forth, reset y forth_all son absolutas. Es decir, que no se les aplican los filtros
#Una de dos, o las hacemos compatibles con los filtros (esto sería lo más lógico) o creamos métodos nuevos.

function getFiltro() {
	local sql=""

	if $only; then
		if [[ $temporada != "-1" ]]; then
			sql="and temporada $otemporada $temporada"
		fi
		if [[ $capitulo != "-1" ]]; then
			sql="$sql and episodio $ocapitulo $episodio"
		fi
	fi
	echo "$sql"
}

function back() {
	local idserie="$1"

	local res=`$SQLITE "select max(id) from episodios where idserie=$idserie and visto>0 $(getFiltro)"`
	if [[ $res != "" ]]; then
		`$SQLITE "update Episodios set visto=0 where id = $res"`
	fi
}

function forth() {
	local idserie="$1"

	local res=`$SQLITE "select min(id) from episodios where idserie=$idserie and visto=0 $(getFiltro)"`
	if [[ $res != "" ]]; then
		`$SQLITE "update episodios set visto=1 where id = $res"`
	fi
}

function reset() {
	local idserie="$1"

	`$SQLITE "update episodios set visto=0 where idserie = $idserie $(getFiltro)"`
}

function forth_all() {
	local idserie="$1"

	`$SQLITE "update episodios set visto=1 where idserie = $idserie $(getFiltro)"`
}

function parseSerie () {
	local chain="$1"

	IFS='|' read -r -a array <<< "$chain"
	local serie="${array[1]}"

	echo "$serie"
}

function parseIDSerie () {
	local chain="$1"

	oIFS=$IFS
	IFS='|' read -r -a array <<< "$chain"

	local serie="${array[0]}"
	IFS=$oIFS

	echo "$serie"
}

function parseIDEpisodio () {
	local chain="$1"

	oIFS=$IFS
	IFS='|' read -r -a array <<< "$chain"

	local episodio="${array[0]}"
	IFS=$oIFS

	echo "$episodio"
}

function parseEpisodio () {
	local chain="$1"

	oIFS=$IFS
	IFS='|' read -r -a array <<< "$chain"

	local episodio="${array[3]}"
	IFS=$oIFS

	echo "$episodio"
}

function parseServicio () {
	local chain="$1"

	oIFS=$IFS
	IFS='|' read -r -a array <<< "$chain"

	local episodio="${array[4]::-4}"
	IFS=$oIFS

	echo "$episodio"
}

function parseEnlace () {
	local chain="$1"

	oIFS=$IFS
	IFS='|' read -r -a array <<< "$chain"

	local episodio="${array[3]}"
	IFS=$oIFS

	echo "$episodio"
}

function fixTemporada() {
	local tempo=""
	local tempn=""

	if [[ $temporada == "-1" ]]; then
		return
	fi

	for (( i=0; i<${#temporada}; i++ )); do
	 	c="${temporada:$i:1}"
	 	echo "Caracter $1: $c"
	  	if [[ $c =~ [0-9] ]]; then
		  	break
		else
			tempo="$tempo$c"
	  	fi
	done
	tempn="${temporada:$i}"

	if [[ $tempo = "" ]]; then
		otemporada="="
	else
		otemporada="$tempo"
	fi
	temporada="$tempn"
	#echo "Operador: $tempo / Número: $tempn"
}

function fixCapitulo() {
	local cappo=""
	local capn=""

	if [[ $capitulo == "-1" ]]; then
		return
	fi
	for (( i=0; i<${#capitulo}; i++ )); do
	 	c="${capitulo:$i:1}"
	 	echo "Caracter $1: $c"
	  	if [[ $c =~ [0-9] ]]; then
		  	break
		else
			capo="$capo$c"
	  	fi
	done
	capn="${capitulo:$i}"

	if [[ $capo = "" ]]; then
		ocapitulo="="
	else
		ocapitulo="$capo"
	fi

	capitulo="$capn"
	#echo "Operador: $tempo / Número: $tempn"
}

function help {
	echo "$CODENAME $VERSION - Copyleft (GPL v3) Julio Serrano 2017"
	echo "Consulta la base de datos creara con sbpopulate"
	echo
	echo "Modo de empleo: $CODENAME [opción] <cadena de búsqueda>"
	echo
	echo " Ejemplos:"
	echo "	$CODENAME discovery"
	echo
	echo "	$CODENAME -t 9 se ha escrito un crimen"
	echo
	echo "	$CODENAME -t 1 -c 7 el mentalista"
	echo
	echo "	$CODENAME -t 2 -c 2 -s streamcloud the orville"
	echo
	echo "	$CODENAME -v -s streamcloud poldark"
	echo
	echo "Opciones"
	echo " -t"
	echo "      Filtrar por temporada."
	echo
	echo " -c"
	echo "      Filtrar por capítulo."
	echo
	echo " -s"
	echo "      Filtrar por servicio."
	echo
	echo " -v"
	echo "      Mostrar temporadas y episodios ya vistos."
	echo
	echo " -l"
	echo "      Limitar listado de episodios listados en pantalla a 10."
	echo
	echo " -o"
	echo "      Solo marcar o desmarcar episodios como vistos y salir."
	echo "      Esta opción permite aplicar las opciones -t y -c para marcar o desmarcar la temporada o el episodio indicado, pero sólo con las funciones --reset y --forth-all."
	echo
	echo " -n"
	echo "      Ver el siguiente episodio pendiente. Cuando ve una serie con qs, la base de datos se actualiza de forma que se marca el episodio como visto. Esto permite a qs saber cual es el siguiente episodio a ver."
	echo
	echo "Opciones del puntero de vistos"
	echo
	echo "      La base de datos lleva la cuenta de los episodios que ya ha visto. Con esa información, qs mantiene una especie de puntero que le indica siempre cual es el siguiente episodio a ver de una serie. Pero eso podría no ser suficiente. Las siguientes opciones pueden manipular ese puntero."
	echo " -b o --back"
	echo "      Mover el putero de la serie una vez hacia atrás. Pudiendo poner tantas b's como se quiera para mover el puntero tal número de veces."
	echo
	echo " -f o --forth"
	echo "      Mover el putero de la serie una vez hacia adelante. Pudiendo poner tantas f's como se quiera para mover el puntero tal número de veces."
	echo
	echo " -a o --forth-all"
	echo "      Marcar todos los episodios de una serie como vistos."
	echo
	echo " -r o --reset"
	echo "      Marcar todos los episodios de una serie como no vistos."
	echo
	echo " -o o --only"
	echo "      Permite manipular el puntero solo en una temporada. Solo funciona en conjunto con -t."
	echo
	echo " -g o --first"
	echo "      Ir directamente al primer enlace disponible de ese episodio. Funciona también con -s."
	echo
	echo " -e o --exit"
	echo "      Salir una vez se han realizado operaciones del puntero de la serie. Un ejemplo de esto sería si ha empezado a ver un episodio de una serie pero no lo ha terminado. Antes de que se le olvide, puede hacer un -b -e y qs volverá a reproducir el episodio que quiere en la siguiente ocasión."
	echo
}

#################################################################################################
# P R O G R A M A      P R I N C I P A L
#################################################################################################

TEMP=`getopt -o ht:c:s:lvnbfaroge --long "help,temporada:,capitulo:,servicio:,limit,next,back,forth,forth-by:,forth-all,back-by:,reset,only,first,exit" -- "$@"`



if [ $? != 0 ]; then help; exit 1; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"


# Debug
#echo "$TEMP"

# VER_NO_VISTOS=false
# VER_VISTOS=false
forth_number=0
forth_all=false
reset=false
# reset_by=false
back=0
# reset_data=()
temporada=-1
otemporada=""
capitulo=-1
ocapitulo=""
servicio=""
limit=false
vervistos=false
gonext=false
only=false
first=false #Ir al primer enlace
salir=false #Salir tras actualizar la base de datos

while true; do
  case "$1" in
  	-h | --help ) help; exit ;;
	-t | --temporada ) temporada=$2; shift ;;
	-c | --capitulo ) capitulo=$2; shift ;;
	-s | --servicio ) servicio=$2; shift ;;
	-l | --limit ) limit=true ;;
	-v ) vervistos=true ;;
	-n | --next ) gonext=true ;;
	-b | --back ) let back++ ;;
	-f | --forth ) let forth_number++ ;;
	--forth-by ) forth_number=$2; shift ;;
	-a | --forth-all ) forth_all=true ;;
	--back-by ) back=$2; shift ;;
    # -v ) VER_VISTOS=true ;;
	-r | --reset ) reset=true ;;
	-o | --only ) only=true ;;
	-g | --first ) first=true ;;
	-e | --exit ) salir=true ;;
	# -m | --mreset ) reset_data+=("$2"); shift ;;
	# --reset-by ) reset_by=true; bydata=$2; shift ;;
    * ) break ;;
  esac
  shift
done

if [[ $1 = "--" ]]; then
	shift
fi

#Retiramos el operador si lo hubiera de temporada y capitulo
fixTemporada
fixCapitulo

# echo "Parámetros: $temporada $capitulo $servicio"
# echo "Argumentos: $1 $2 $3 $4 $5 $6 $7 $8 $9"
# PARM=""
# for arg in $@; do
# 	if [[ $1 != "--" ]]; then
# 		PARM="$PARM$1 "
# 	fi
# 	shift
# done

#PARM=$(trim $PARM)

echo "$CODENAME $VERSION - Copyleft (GPL v3) Julio Serrano 2017"
echo "Consulta la base de datos creada con sbpopulate para obtener enlaces de tus series."
echo

if $only; then
	if [[ $temporada == -1 ]] && [[ $capitulo == -1 ]]; then
		echo
		echo "No tiene sentido activar la opción -o si no se da algún dato más."
		echo
		exit
	fi
fi

SERIES=$(querySeries "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9")

if [[ $SERIES = "" ]]; then
	echo "No hay series en la base de datos que coincidan con esa cadena de búsqueda."
	echo "Use qspopulate con la url de una serie para rellenarla"
	exit
fi



#Dividir series por nueva línea
readarray -t aseries <<<"$SERIES"


if [[ ${#aseries[*]} == 1 ]]; then
	CHOSENID=0
	echo "El sistema ha devuelto sólo una serie, por lo que se asume esa es que desea."
else
	echo "Series que coinciden con su cadena de búsqueda: "
	echo
	#Recorrer el array resultante "y"
	let i=0
	for t in "${aseries[@]}"; do
		nombreserie=$(parseSerie "$t")
		echo "	$i:	$nombreserie"
		((i++))
	done

	LIMITE=$(( ${#aseries[*]} - 1 ))
	CHOSENID=$(userChoice $LIMITE "Seleccione la serie:")
fi

#echo "El elegido es: ${aseries[$CHOSENID]}"
echo

#Extraer el nombre de la serie para futuros usos
SERIE=$(parseIDSerie "${aseries[$CHOSENID]}")


nombreserie=$(parseSerie "${aseries[$CHOSENID]}")
echo "Ha escogido $nombreserie"

#############################
# Ajustar puntero de vistas
#############################
#reset
if $reset; then
	reset "$SERIE"
fi
#forth-all
if $forth_all; then
	forth_all "$SERIE"
fi
#Ir atrás
while [[ $back > 0 ]]; do
	res=$(back "$SERIE")
	
	let back--
done
unset res

#Ir adelante
while [[ $forth_number > 0 ]]; do
	res=$(forth "$SERIE")
	
	let forth_number--
done
unset res

if $only; then
	echo
	echo "Se ha activado --only"
	echo "Se han actualizado los episodios vistos."
	echo
	exit
fi

if $salir; then
	echo
	echo "Se ha activado --exit"
	echo "Se han realizado las operaciones solicitadas. Saliendo..."
	echo
	exit
fi

if [[ $temporada == -1 ]]; then
	TEMPORADAS=$(queryTemporadas "$SERIE")

	if [[ $TEMPORADAS = "" ]]; then
		echo "No hay episodios pendientes en esta serie."
		echo "Use qspopulate con la url de una serie para rellenarla."
		echo "O, si ya las ha visto todas y desea volver a hacerlo, invoque de nuevo a qs con la opción -r."
		exit
	fi


	echo "Temporadas pendientes:"
	echo
	readarray -t atemporadas <<<"$TEMPORADAS"

	if [[ ${#atemporadas[*]} == 1 ]] || $gonext; then
		echo "* [Sólo hay una temporada, seleccionada automáticamente]"
		CHOSENID=0
	else
		let i=0
		for t in "${atemporadas[@]}"; do
			echo "	$i:	Temporada $t"
			((i++))
		done

		LIMITE=$(( ${#atemporadas[*]} - 1 ))
		CHOSENID=$(userChoice $LIMITE "Seleccione la temporada: ")
	fi

	TEMPORADA="${atemporadas[$CHOSENID]}"
else
	TEMPORADA="$temporada"
fi

echo "Ha elegido la temporada $TEMPORADA"

echo

if [[ $capitulo == -1 ]]; then

	EPISODIOS=$(queryEpisodios "$SERIE" "$TEMPORADA")

	if [[ $EPISODIOS = "" ]]; then
		echo "No hay episodios pendientes en esta serie."
		echo "Si ya los ha visto todos y quiere volver a hacerlo, invoque qs de nuevo, esta vez con la opción -r"
		exit
	fi

	echo "Episodios de la temporada $TEMPORADA:"
	echo

	readarray -t aepisodios <<<"$EPISODIOS"

	if $gonext; then
		echo "* [Opción --next. Saltando al siguiente episodio]"
		CHOSENID=0
	else
		let i=0
		for t in "${aepisodios[@]}"; do
			echo "	$i:	Episodio $(parseEpisodio $t)"

			if $limit; then
				if (( i == 10 )); then
					RESTANTES=$(( ${#aepisodios[*]}-10 ))
					echo "* [Salida limitada a 10 episodios - $RESTANTES restantes]"
					break
				fi
			fi
			((i++))
		done

		LIMITE=$(( ${#aepisodios[*]} - 1 ))
		CHOSENID=$(userChoice $LIMITE "Seleccione el episodio que quiere ver: ")
	fi

	EPISODIO="${aepisodios[$CHOSENID]}"
	IDEPISODIO=$(parseIDEpisodio "$EPISODIO")
else
	EPISODIO=$(queryEpisodio "$SERIE" "$temporada" "$capitulo")
	echo "$EPISODIO"
	IDEPISODIO=$(parseIDEpisodio "$EPISODIO")

fi

echo "Ha escogido el episodio $EPISODIO --> código $IDEPISODIO"

echo


if [[ $servicio == 0 ]]; then
	ENLACES=$(queryEnlaces "$SERIE" "$IDEPISODIO")
else
	ENLACES=$(queryEnlacesFiltro "$SERIE" "$IDEPISODIO" "$servicio")
fi

if [[ $ENLACES = "" ]]; then
	echo "No hay enlaces para este episodio."
	exit
fi

echo "Enlaces del episodio $EPISODIO de la temporada $TEMPORADA: "
echo

readarray -t aenlaces <<<"$ENLACES"

let i=0
for t in "${aenlaces[@]}"; do
	echo "	$i:	$(parseServicio $t)"
	((i++))
done

LIMITE=$(( ${#aenlaces[*]} - 1 ))

if $first; then
	CHOSENID=0
else
	CHOSENID=$(userChoice $LIMITE "Seleccione el enlace: ")
fi

ENLACE=$(parseEnlace "${aenlaces[$CHOSENID]}")

echo "Este es el enlace que ha seleccionado:"
echo
echo "$ENLACE"
echo
echo "Que disfrute del episodio!"

VISTO=$(setVisto "$IDEPISODIO")
echo "$VISTO"
