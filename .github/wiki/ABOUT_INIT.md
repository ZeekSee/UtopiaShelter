# Инициализация объектов, использование ``/atom_init()`` и ``/New()``

* Коротко - ключевые слова о которых здесь будет идти речь:
  * atom_init
  * atom_init_late
  * INITIALIZE_HINT_LATELOAD
  * INITIALIZE_HINT_QDEL

С момента внедрения более продвинутой системы инициализации для класса `/atom`, мы отошли от использования встроенной в бъенд процедуры `/New(...)`. Само использование `New` крайне не приветствуется и как правило делает что-нибудь хуже. Однако есть очень редкие моменты, когда только по старому и можно заставить что-то работать, но об этом позже и ниже.

### Debug:

Подняв локальный сервер (или не локальный) и имея права, вы можете обнаружить во вкладке `debug` кнопку `Display Initialzie() Log`. Там будут отображаться ошибки связанные с atom_init и его выполнением, например:
```
Path : /obj/item/stack/cable_coil/cut/red 
- Didn't return an atom_init() hint
```

Поэтому если ваша фича связана как-то с инициализацией, не забудьте при тестах глянуть и в это окно.

### Важно:

* В `atom_init` не должно быть что-либо связанного с sleep() или того, что может поместить всю процедуру в сон. Т.е нужно учитывать и все, что ваш atom_init вызывает, и чтобы в этих вызовах тоже не было ничего из этого.
* В `atom_init` не должен быть использован qdel ни на себе "qdel(src)" ни на ком либо другом. Как это - вы спросите? Не спешите делать выводы, ниже будет расписано как выходить из этой ситуации.
* В `atom_init` обязан присутствовать `. = ..()` - т.е вызов родителя с возвратом результата. Что такое `.` и что такое `..()` вы можете почитать в доках бъенда или на крайняк спросить у людей, а полный прок выглядит так:
```
/mob/something/atom_init()
	. = ..()
	здесь и ниже идет ваш код, ну или выше, если вам нужна особая последовательность вызовов.
```

### Синтаксис для atom_init():

* Если нам не надо передавать аргументы в скобках:
```
/obj/something/atom_init()
```
* Если вам надо передать аргументы в скобках:
```
/mob/something/atom_init(mapload, arg1, arg2, arg3, ...)
```
Заметили что первым идет mapload, а не loc как при использовании New(loc, arg1, arg2, arg3, ...)?
Так вот, мы не передаем в atom_init loc, loc уже выставлен или не выставлен на самом атоме к моменту начала вызова atom_init (в зависимости от того, создавался ли атом сразу по каким-то координатам или нет).
Первым всегда **обязан** быть **mapload** и только после него идут какие-то ваши.
Если вы выставите первым какой-нибудь свой аргумент, то считайте ваш код не будет исправно работать.

***

### Что еще за аргумент mapload?

Этот аргумент является TRUE когда контроллеры впервые инициализируются (т.е поднялся сервер) и во время загрузки карты через мап лоадер. В обычное время будет он FALSE. А как это использовать уже решать вам, но на примере шкафов это выглядит след. образом: нам надо чтобы при старте сервера или загрузке карты, вещи которые находятся на том же турфе что и шкаф, автоматически помещались внутрь шкафа, а в остальное время если игрок например построил шкаф под чем-то или кем-то - нет.

***

### Более подробно про atom_init и хитростях с кудель:

Да, выше текст это совершенно далеко от полноценной информации и лишь позволяет понять самое необходимое и основное, т.е две вещи - вместо New() теперь этот atom_init(), а еще то, что в нем обязан быть вызов родителя с возвратом результат `. = ..()`, хотя вызов родителя `..()` и в New() обязан был быть но теперь еще и с возвратом. Однако это не даст в полную силу использовать это.

Итак, у нас есть два дефайна "хинта" `INITIALIZE_HINT_LATELOAD` и `INITIALIZE_HINT_QDEL`. Что такое дефайны (define), вы уже должны знать читая это, поэтому не ищите тут ответ.

### INITIALIZE_HINT_LATELOAD:
```
/atom/something/atom_init()
	..()
	здесь какой-нибудь прочий код, если есть.
	return INITIALIZE_HINT_LATELOAD
```
Заметили что `. = ..()` поменялся на `..()`? Это все потому, что нас не интересует уже что вернет нам родитель (нам только сам вызов его важен), и мы сами говорим что возвращаем результатом, в данном случае хотим вызвать еще прок поздней инициализации, а точнее atom_init_late() сказав `return INITIALIZE_HINT_LATELOAD`.

Собственно после того, как атом пройдет фазу выполнения atom_init(), то после этого пойдет уже вторая фаза в которой будет вызван atom_init_late().
Сам atom_init_late() уже не обязан ни вызвать родителя, не уж тем более возвращать результат (второе кстати вообще бесполезно и не нужно). Еще он не поддерживает изначально аргументы, поэтому этот вопрос вам надо решать в atom_init().

### qdel и atom_init_late

Помните выше было написано про запрет использования qdel в atom_init? Вот atom_init_late как раз отлично подходит для этого дела.

### INITIALIZE_HINT_QDEL

```
/atom/something/atom_init()
	..()
	здесь какой-нибудь прочий код, если есть.
	return INITIALIZE_HINT_QDEL
```

Тоже как и в предыдущем случае, но только другой хинт.
Означает, что после того как выполнится вся цепочка atom_init, мы должны вызвать qdel(src) - т.е удалить самого себя. Это полезно во всяких спавнерах, но таких, которые должны после создания удалить себя из мира сего, и в случае если нужно удалить кого-то другого или это может выполниться в ком-то другом, тогда стоит использовать позднюю инициализацию - INITALIZE_HINT_LATELOAD.

### Комбо-пример для уже совсем взрослых (без описания):

```
/mob/someclass/atom_init(mapload, health = 250, expl_range = 10)
	. = ..()
	if(expl_range < 0)
		return INITIALIZE_HINT_LATELOAD
	else if(prob(50))
		new /mob/someclass/larva(src)
		return INITIALIZE_HINT_QDEL
	else
		src.health = health

/mob/someclass/atom_init_late()
	for(var/i in 1 to 5)
		new /obj/item/diamond(src)
	explosion(src, 5) // so we throw diamonds around
	if(!QDELETED(src)) // incase explosion didn't gib us.
		qdel(src)
```

***

### Так когда же все таки можно использовать New()?

Лично знаю пока только один случай - это когда нам надо сделать что-то, когда еще не инициализированы контроллеры и зашедший игрок на сервер, потребует например спавн поинт, который уже должен быть для него создан.
На вашей же практике при работе с атомами мало вероятно будет такой случай, поэтому скорее всего вам не придется об этом думать.

***


Пожалуй вот теперь у вас должна быть более полная картина что такое atom_init, как быть с qdel, и тому подобное.