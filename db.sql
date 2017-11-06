CREATE TABLE series (id integer primary key autoincrement, titulo varchar, enlace varchar);
CREATE TABLE episodios (id integer primary key autoincrement, idserie integer, temporada integer, episodio integer, visto integer, foreign key(idserie) references series(id));
CREATE TABLE enlaces (id integer primary key autoincrement, idserie integer, idepisodio integer, enlace varchar, url varchar, foreign key(idserie) references series(id), foreign key(idepisodio) references episodios(id));
.exit
