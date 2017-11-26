# sb web scraper
sb es un conjunto de scripts de bash que partiendo de un web scraping obtienen enlaces a los episodios de 
nuestras series favoritas.

Funciona de la siguiente manera, ejecutas sb o qs añadiendo como argumento una cadena de búsqueda y 
algunas opciones como la temporada y el número del episodio que quieres ver, y obtienes los enlaces 
oportunos para ver el episodio en tu navegador en cuestión de segundos.

Aprender a manejar estos scripts es muy fácil y no requiere más de cinco o diez minutos, incluso si 
no sabes nada sobre el terminal.

Ahora vayamos script por script.
## sb

Este script es el web scraper principal y el más directo. Se invoca con una serie de palabras 
clave y te permite buscar tu serie y dejarte elegir temporada y episodio para finalmente darte los 
enlaces. También puedes incluir antes de las claves los argumentos -t n y/o -c n, con los que 
podrás ir directamente al episodio de la temporada que quieres ver. Otra forma de filtrar es por 
servicios de streaming o descarga. Hay episodios que tienen más de 300 enlaces. Con la opción -s 
puedes indicar el servicio que prefieres. Veamos unos ejemplos.

	sb palabras clave de tu serie

Este comando te permite buscar tu serie y luego la elección de temporada y episodio será manual. El script te preguntará.

	sb -t 2 palabras clave de tu serie

Este otro te permite buscar la serie que quieras, pero te mostrará solo episodios de la segunda temporada.

	sb -t 2 -c 11 palabras clave

Este comando va directo al episodio 11 de la segunda temporada. Antes de eso tendrás que confirmar la serie entre las encontradas con tu cadena de búsqueda, como en todos los otros comandos.

	sb -t 2 -c 11 -s streamcloud palabras clave

Este comando es igual que el interior, pero te filtrará los enlaces por servicio y te mostrará únicamente los de streamcloud. También puedes usar palabras incompletas, como "stream" o lo que se te ocurra.

## qspopulate

El comando sb está bien. Funciona. Pero en cada vez que lo ejecutamos se tienen que realizar varias 
peticiones web, lo que hace que su respuesta no sea verdaderamente rápida. Además, si dentro de un 
tiempo quieres ver el mismo episodio de nuevo, se tiene que realizar el mismo número de peticiones 
que la primera vez. Me pregunto... ¿Qué pasaría si nos pudiéramos descargar toda la información de 
una serie y ponerla en una base de datos? Pues eso es qspopulate. Funciona de forma parecida a sb, 
pero si especificamos una temporada y un episodio, entonces no nos mostrará ese episodio sino que 
rellenará una base de datos con la toda información de la serie a partir de la temporada y el 
episodio elegido. Una vez terminado el proceso, que va a llevar su tiempo, sobre todo si la serie 
tiene muchas temporadas, tendremos todo indexado en una base de datos accesible con el siguiente 
script: qs.

El comando qspopulate tiene una pega y es que genera un buen número de peticiones. Por lo tanto os 
pido que no hagáis un uso intensivo de este script.

## qs

qs parte de la base de datos creada con el script anterior y permite consultarla y recuperar los datos que necesitemos. Pero no solo eso, sino mucho más. Lleva un registro de los episodios ya vistos y actúa en consecuencia en las subsiguientes llamadas. Eso nos permitirá llevar el control de por donde nos llegamos en cada serie. Veamos algunos ejemplo comentados.

	qs -n palabras clave de la serie

Obtener los enlaces del siguiente episodio de la serie indicada en las palabras clave.

	qs -n -s powvideo palabras clave

Obtener los enlaces de powvideo del siguiente episodio pendiente de la serie indicada.

	qs -t 10 -c 4 -s streamcloud palabras claves

Obtener los enlaces de streamcloud del episodio cuarto de la décima temporada.

	qs --forth-all palabras claves

Marcar como vistos todos los episodios de la serie.

	qs --reset palabras claves

Marcar como no vistos todos los episodios de la serie.

	qs -f palabras clave

Marcar el siguiente episodio pendiente como visto.

	qs -b palabras clave

Marcar el último episodio visto como no visto.

	qs -bbb colombo

Retroceder tres episodios en la serie Colombo. Esto también funciona con -fff con el efecto contrario. Se pueden poner el número de b's o de f's que se quieran hasta cierto punto (límites de la línea de comandos).

qs siempre pregunta cual de las series es la correcta, porque parte de una búsqueda. Aunque esta vez sea solo de la base de datos. Y una vez seleccionada, realiza las acciones -f, -b, --reset y cualquier otra opción indicada, y después permite obtener enlaces de el episodio que se quiera teniendo en consideración el resultado de ejecutar las opciones.







