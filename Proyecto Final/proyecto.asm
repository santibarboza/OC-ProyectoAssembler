%define largoLinea 10001	;es el largo de la linea +1 para poder agregarle un \0
section .bss
	bufferGral resb  largoLinea	;buffer general donde guardamos lo que leemos
	buffer1 resb largoLinea		;buffer para guardar una linea
	buffer2 resb largoLinea		;buffer para guardar otra linea
	patron	resb largoLinea		;es el patron a buscar en lineas
	extra resb largoLinea		;buffer para mostrar numero de linea, ayuda,etc
section .data
	numLinea dd 1		;numero de linea actual
	salida dd 1		;salida del informe(descriptor de archivo)
	pArchivo dd 0		;descriptor del archivo
	anterior dd buffer2	;puntero al buffer de la linea anterior
	largo_anterior dd 0	;es la cantidad de bytes de la linea anterior
	actual dd buffer1	;puntero al buffer de linea actual
	largo_actual dd 0	;es la cantidad de bytes de la linea actual
	posActual dd buffer1	;puntero a la sig posicion a insertar un byte en la linea actual
	posBuffer dd 0		;puntero a la siguiente posicion a leer del bufferGral
	imprimir_ant db 0	;indica si se debe imprimir la anterior linea
	imprimir_sig db 0	;indica si se debe imprimir la siguiente linea
	imprimir_Actual db 0	;permite imprimir la siguiente linea ni bien la leemos
	termino_Arch db 0	;termino de leer el archivo
	salto db 10		;Descriptor del salto
	help dd "-h",0		;para comparar con -h
	before dd "-b",0	;para comparar con -b
	after dd "-f",0	;para comparar con -f
	fin dd 0		;puntero a la ultima posiciona leer del bufferGral
	finBuffer dd bufferGral+largoLinea	;puntero al final del bufferGral
	mensaje_help db 10,"----------------------------------\-\HELP/-/------------------------------------",10,
	db "Programa para obtener aquellas lineas del archivo que contengan el patron especificado.",10,10,
	db"El formato y las opciones de invocacion son las siguientes: ",10,10,
	db"Sintaxis:",10,10,09,"$ bus [ -h ] patrón archivo_entrada [archivo_salida] [ -b ] [ -f ] ",10,10,
	db "*Los parametros entre corchetes denotan parametros opcionales.",10,10,
	db "*Si se especifica la opcion -h muestra una ayuda por pantalla detallando el proposito y funciones opcionales del programa.",10,10,
	db "*Si se especifica archivo_salida se guardara la salida del programa en el archivo especificado.",10,10,
	db "*Si no se especifica el archivo_salida se mostrara la salida del programa en la consola.",10,10,
	db "*Si se especifica -b entonces se mostrara la linea anterior a parte de la linea encontrada.",10,10,
	db "*Si se especifica -f entonces se mostrara la linea siguiente a parte de la linea encontrada.",10,
	db "----------------------------------------------------------------",10
	largo_mhelp equ $-mensaje_help

section .text
	global _start

_start:
	pop EDX			;saco ArgC
	cmp EDX,2		;lo comparo con 2
	jl salir_Error_Other	;si ARGC<2 = Error Parametros

leerParametro:
	;lee todos los "EBX" parametros ingresados
	;Si estan mal ingresados entonces ...
	pop EBX		;EBX <- Nombre del archivo
	pop EBX		;EBX <- Puntero al 1er  argumento
	

	mov EAX,help		;cargamos en EAX "-h"
	call comparar_cadena


	;En EBX tengo el 1er argumento
	;EAX = 1 si se ingreso "-h"
	cmp EAX,1		;si se ingreso -h?
	je imprimirAyuda	;

	;No se ingreso "-h"
	;EDX=agrc (cant de argumentos)

	cmp EDX,3		;tiene al menos 3 argumentos
	jl salir_Error_Other	; si tiene menos de 2 parametros,salgo

	cmp EDX,6		;tiene a lo sumo 6 argumentos
	jg salir_Error_Other	; si tiene mas de 5 parametros,salgo

	call cargarPatron	;guardo el patron (1er arg)
	pop EBX			;guardo el archivo
	
	
abrirArchivo:
	;Abre el Archivo, cuyo nombre esta cargado en EBX.
	;Si produce error la lectura, sale con Error de input.
	;Sino, guarda el descriptor del archivo en la direcion pArchivo.

	mov EAX,5	;sys_open
	mov ECX,0	;modo=Read_Only
	int 80h

	;Tengo qe Controlar que esta abierto Y EXISTE
	test EAX,EAX		;Me aseguro de que es valido
	js salir_Error_Input	; si hubo error de apertura, salis con error



	;Abri el archivo sin errores
	mov [pArchivo],EAX	;archivo <- descriptor del archivo

	cmp EDX,4	;tiene al menos 4 argumentos?
	jl comienzo	;si posee menos de 3 parametros ,saltea el siguiente codigo 

	;Controla Parametros Opcionales
	;tenemos parametros opcionales como [arch_sal], [-b] o [-f]

	cmp EDX,4	;tiene un solo parametro opcional
	jg arg6		;tiene mas de un parametro opcional

	;Tengo un solo parametro opcional
	;veo si es -b, -f o arch_sal

	;comparo con -b
	pop EBX			;EBX<-argv[3]
	mov EAX,before		;EAX<-"-b"
	call comparar_cadena	;compara argv[3] con "-b"

	;EAX = 1 si argv[3] == "-b"
	cmp EAX,1		;si se ingreso -b?
	jne arg4_f		;sino en -b, ve si es -f

	;argv[3]=="-b"
	mov BYTE[imprimir_ant],1	;seteo el flag para imprimir la linea anterior
	jmp comienzo			;termine de leer parametros
arg4_f:
	;comparo con -f
	mov EAX,after		;EAX<-"-f"
	call comparar_cadena	;compara arg[3] con "-f"

	;EAX = 1 si arg[3] == "-f"
	cmp EAX,1		;si se ingreso -b?
	jne arg4_AS		;sino en -f, ve si es el archivo de salida

	;argv[3]=="-f"
	mov BYTE[imprimir_sig],1	;seteo el flag para imprimir la siguiente linea
	jmp comienzo			;termine de leer parametros
arg4_AS:
	call cargar_AS
	jmp comienzo
arg6:
	;Controla si tiene 3 los parametros 
	cmp EDX,6		;tiene 3 parametros opcionales?
	jne arg5		;sino tiene 3 controla si tiene 2 parametros opcinales

	;Intento leer el archivo de salida
	pop EBX		;EBX <- argv[3]
	call cargar_AS	;controlo el arch_salida

	;comparo argv[4] con "-b"
	pop EBX			;EBX<-argv[4]
	mov EAX,before		;EAX<-"-b"
	call comparar_cadena	;comparo argv[4] con "-b"
	
	cmp EAX,1		;(argv[4]=="-b")?
	jne salir_Error_Other	;parametro erroneo? salgo
	
	;argv[4]=="-b"
	mov BYTE[imprimir_ant],1	;seteo el flag para imprimir la linea anterior

	;comparo argv[5] con "-f"
	pop EBX			;EBX<-argv[5]
	mov EAX,after		;EAX<-"-f"
	call comparar_cadena	;comparo argv[5] con "-f"
	
	cmp EAX,1		;(argv[5]=="-f")?
	jne salir_Error_Other	;parametro erroneo? salgo
	
	;argv[5]=="-f"
	mov BYTE[imprimir_sig],1	;seteo el flag para imprimir la linea siguiente
	jmp comienzo		
arg5:
	;Tiene 2 parametros opcionales
 
	;comparo argv[3] con -b
	pop EBX			;EBX<-argv[3]
	mov EAX,before		;EAX<-"-b"
	call comparar_cadena	;compara argv[3] con "-b"

	;EAX = 1 si argv[3] == "-b"
	cmp EAX,1		;si se ingreso -b?
	jne arg5_AS		;sino en -b, ve si es el archivo de entrada
	
	;se que argv[3]=="b"
	mov BYTE[imprimir_ant],1	;seteo el flag para imprimir la linea anterior

	;comparo argv[4] con "-f"
	pop EBX			;EBX<-argv[4]
	mov EAX,after		;EAX<-"-f"
	call comparar_cadena	;comparo argv[4] con "-f"
	
	cmp EAX,1		;(argv[4]=="-f")?
	jne salir_Error_Other	;parametro erroneo? salgo
	
	;argv[5]=="-f"
	mov BYTE[imprimir_sig],1	;seteo el flag para imprimir la linea siguiente
	jmp comienzo			
arg5_AS:
	call cargar_AS	;controlo el arch_salida

	;comparo argv[4] con "-b"
	pop EBX			;EBX<-argv[4]
	mov EAX,before		;EAX<-"-b"
	call comparar_cadena	;comparo argv[4] con "-b"
	
	cmp EAX,1		;(argv[4]=="-b")?
	jne arg5_f		;lei arch_sal y -b 
	
	;argv[4]=="-b"
	mov BYTE[imprimir_ant],1	;seteo el flag para imprimir la linea anterior
	jmp comienzo			;termine de leer los parametros
arg5_f:	
	;comparo argv[4] con "-f"
	mov EAX,after		;EAX<-"-f"
	call comparar_cadena	;comparo argv[5] con "-f"
	
	cmp EAX,1		;(argv[5]=="-f")?
	jne salir_Error_Other	;parametro erroneo? salgo
	
	;argv[5]=="-f"
	mov BYTE[imprimir_sig],1	;seteo el flag para imprimir la linea siguiente
	
comienzo:
	call recargarBuffer	;inicializo el bufferGral

ProgPpal:
	;Realiza la tarea principal
	;Ya se inicializo patron,archivo,y los flags
	;en salida se abrio un archivo de salida si se requirio


	call resetPosActual
	call obtenerLinea	;actualiza el bufferActual

	;Tenemos el bufferActual actualizado

	cmp BYTE[imprimir_Actual],1	;si imprimir_Actual==1
	jne Busc			;salteo el then si no se cumple

	;Imprimo la siguiente linea de la anterior iteracion
	mov ECX,[actual]		;imprimir actual
	mov EDX,[largo_actual]		;largo de impresion
	call imprimir			;imprime la linea
	mov BYTE [imprimir_Actual],0	;reseteo el flag de imprimir_Actual
Busc:

	;buscar Patron en la cadena
	mov EAX,[actual]	;cargo en EAX la linea Actual
	mov EBX,patron		;cargo en EBX el patron a buscar
	call buscar_cadena	; busca el patron en la linea Actual


	cmp EAX,1		;Encontro el patron en la linea Actual?
	jne swap_inc

	;Encontramos el patron en la linea Actual
	call imprimirSalto		;imprimimos un salto de linea

	cmp BYTE[imprimir_ant],1	;hay que imprimir la linea anterior?
	jne impAct
	
	;Encontro el patron en la linea Actual
	;tenemos  que imprimir la linea Anterior
	mov ECX,[anterior]		;asignamos anterior a imprimir
	mov EDX,[largo_anterior]	;asignamos el largo a imprimir de anterior
	call imprimir			; imprimimos en Salida
impAct:
	call imprimirNroLinea	;nos imprime el numero de linea seguido de un ". "

	;Imprimir Linea Actual
	mov ECX,[actual]	;asignamos actual a imprimir
	mov EDX,[largo_actual]	;asignamos el largo a imprimir de actual
	call imprimir		;imprimimos la linea Actual

	cmp BYTE [imprimir_sig],1 ; si hay que imprimir la siguiente linea
	jne swap_inc

	;tenemos que imprimir la siguiente linea
	mov BYTE[imprimir_Actual],1	;seteo el Flag Imprimir_Actual para
					;que en la siguiente iteracion imprima su actual

swap_inc:
	;incrementamos el numero de linea
	mov EAX, [numLinea]	;EAX <- numero de Linea
	inc EAX			;incrementamos el numero de Linea
	mov [numLinea],EAX	;actualizamos el numero de Linea

	;Swap del buffer Actual por el Anterior
	mov EAX,[anterior]		;guardamos la referencia de anterior
	mov EBX,[actual]		;guardamos la referencia de actual
	mov [actual],EAX		;actualizamos el buffer actual
	mov [anterior],EBX		;actualizamos el buffer anterior

	;Actualizamos el Largo de la Linea anterior
	mov EAX,[largo_actual]		;guardamos el largo actual
	mov [largo_anterior],EAX	;actualizamos el largo de la linea anterior
	mov DWORD[largo_actual],0	;resetiamos el largo actual,para no acceder al contenido

	cmp BYTE[termino_Arch],1 	;si terminamos de leer el archivo
	jne ProgPpal			;sino terminamos de leer el archivo vuelvo a ProgPpal

	;Terminamos de leer el archivo con exito
	;Cerramos archivos y terminamos la ejecucion con error 0

	;Cierro el archivo de Entrada
	mov EAX,6		;sys_close
	mov EBX,[pArchivo]	;EBX<-descriptor del Archivo
	int 80h			;syscall

	;Controlo que no se produjeran errores de entrada
	cmp EAX,0		;se cerro bien?
	jne salir_Error_Input	;no se cerro bien,salgo

	;Cierro el archivo de Salida
	mov EAX,6		;sys_close
	mov EBX,[salida]	;EBX <- descriptor del archivo de salida
	int 80h			;syscall

	;Controlo  que no se produjeran errores de salida
	cmp EAX,0		;se cerro bien?
	jne salir_Error_Output	;no cerro bien, salgo

	jmp salir_ConExito

cargar_AS:
	;Carga y checkea el Archivo de salida ingresado en EBX
	;Si produce error la lectura, sale con Error de output.
	;Sino, guarda el descriptor del archivo en la direcion salida.
	
	;Guardo el valor de los registros modficados
	push EAX	;guardo el valor de EAX
	push ECX	;guardo el valor de ECX

	mov EAX,5	;sys_open
	mov ECX,1	;modo=Write_Only
	int 80h

	;Tengo qe Controlar que esta abierto Y EXISTE
	test EAX,EAX		;Me aseguro de que es valido
	js salir_Error_Output	; si hubo error de apertura, salis con error

	;Abri el archivo sin errores
	mov [salida],EAX	;salida <- descriptor del archivo

	;restauro los Registros modificados
	pop ECX		;restauro el valor de ECX
	pop EAX		;restauro el valor de EAX
	ret

cargarPatron:
	;En EBX tiene el puntero al patron
	;Esta funcion copia en el buffer del patron esa cadena
	
	;Guardo los registros que voy a usar
	push EBX	;guarda el valor de EBX
	push ECX	;guarda el valor de ECX
	push EDX	;guardo el valor de EDX
	mov EDX,patron
cargar:
	mov CL,BYTE[EBX]	;guardo el byte apuntado por EBX
	mov BYTE[EDX],CL	;lo guardo en EDX
	inc EBX			;avanzo en el patron
	inc EDX			;avanzo en el buffer

	cmp BYTE[EBX],0		;el byte que voy a leer del patron en null?
	jne cargar
	
	mov CL,BYTE[EBX]	;guardo el \0
	mov BYTE[EDX],CL	;lo inserto al final

	;restauro los valores de los registros
	pop EDX		;Restauro EDX
	pop ECX		;Restauro ECX
	pop EBX		;Restauro EBX
	ret

imprimirNroLinea:
	;Imprime el numero de linea seguido de un ". "
	;Guardo los registros que voy a usar
	push EAX	;guarda el valor de EAX
	push EBX	;guarda el valor de EBX
	push ECX	;guarda el valor de ECX
	push EDX	;guarda el valor de EDX

	mov EAX,[numLinea]	; cargo en numero de linea 
	mov EBX,extra		; cargo buffer para guardar cadena
	call itoa		; convierte el nume en una cadena
	
	;En EAX tengo la cantidad de bytes que guardo
	mov EBX,extra		;EBX<-Extra
	add EBX,EAX		;EBX<- Extra +cantidad de bytes guardados
	
	inc EAX
	mov BYTE[EBX],46	;pongo punto
	inc EBX
	inc EAX
	mov BYTE[EBX],32	; pongo espacio
		
	;Imprimo la cadena
	mov ECX,extra	;cadena a Imprimir
	mov EDX,EAX	;numero de bytes a imprimir
	call imprimir

	;Restauro los valores de los registros modificados
	pop EDX		;restauro EDX
	pop ECX		;restauro ECX
	pop EBX		;restauro EBX
	pop EAX		;restauro EAX
	ret


resetPosActual:
	;Resetea la posicion actual
	push EAX
	mov EAX,[actual]
	mov [posActual],EAX
	pop EAX
	ret



obtenerLinea:

	;Lee la siguiente linea del archivo,actualizando el buffer actual
	;Si es la ultima linea del archivo, guarda un 1 en [termino_arch]

	mov EAX,[posBuffer]	;EAX <- posBuffer
	cmp BYTE[EAX],10	;posBuffer == salto de linea?
	je fuera_Wh_obtL
	
while_obtL:
	;mientras no termine de leer la linea
	;el archivo leo lo que tengo en bufferGral y lo
	;almaceno en el buffer actual.
	;Si se me termina el bufferGral y todabia hay para leer,
	;recargo el BufferGral.si es la ultima linea, guardo un 1 en [termino_arch]

	;Controlo si llege al final del BufferGral	
	mov EAX,[posBuffer]	;EAX<-posBuffer
	cmp EAX,[fin]		;(posBuffer == fin)?
	jne analizarChar
	
	;Llege al final del BufferGral
	;Controlo si tengo otra linea para leer
	mov EAX,[fin]		;EAX<-fin
	cmp EAX,[finBuffer]	;(fin==finBuffer)?
	jne terminoLeer
	
	;Todabia tengo archivos que leer
	call recargarBuffer	;actualiza el bufferGral,la posBuffer y el fin
	jmp obtenerLinea
	
terminoLeer:
	;Termino de leer el archivo
	mov BYTE[termino_Arch],1	;seteamos el flag de ultima linea
	mov BYTE[imprimir_sig],0  	;no imprimira siguiente linea
	jmp fuera_Wh_obtL

analizarChar:	
	call copiarByte	;[posActual] <- [posBuffer]

	;adelanto en el BufferGral
	mov EAX, [posBuffer]	;guardo la posBuffer
	inc EAX			;Incremento la posBuffer
	mov [posBuffer],EAX	;actualizo la posBuffer

	;adelanto en el bufferActual
	mov EAX,[posActual]	;guardo la posActual
	inc EAX			;Incemento la posActual
	mov [posActual],EAX	;actualizo la posActual

	jmp obtenerLinea

fuera_Wh_obtL:
	;Agrega al final del bufferActual los simbolos terminadores
	;Saltea el salto de linea del bufferGral y setea el largo del bufferActual
	
	call addTerminadores	;agregamos los terminadores al bufferActual

	;adelanto en el bufferGral(salteo \n)	
	mov EAX,[posBuffer]	;guardo la posActual
	inc EAX			;Incemento la posActual
	mov [posBuffer],EAX	;actualizo la posActual

	;seteo el largo de Actual
	mov EAX,[posActual]	;
	sub EAX,[actual]	;EAX <-posActual-Actual
	mov [largo_actual],EAX	;actualizamos el largo del bufferActual
	
	ret
	
addTerminadores:
	;Agrega al final del bufferActual los simbolos terminadores
	mov EAX,[posActual]	;
	mov BYTE[EAX],10	;insertamos un \n al final del buffer de la linea actual

	;adelanto en el bufferActual
	mov EAX,[posActual]	;guardo la posActual
	inc EAX			;Incemento la posActual
	mov [posActual],EAX	;actualizo la posActual

	mov EAX,[posActual]	;
	mov BYTE[EAX],0		;insertamos un \0 (null) despues de la cadena Actual
	ret



copiarByte:
	;copia el byte de posBuffer en el byte de posActual
	push EAX
	push EDX		;guardo el valor de EDX
	mov EAX,[posBuffer]	;EAX<-posBuffer
	mov DL,BYTE[EAX]	;DL <- [posBuffer]
	mov EAX,[posActual]	;EAX<-posActual
	mov BYTE[EAX],DL	;[posActual]<-DL
	pop EDX			;restauro EDX
	pop EAX			;restauro EAX
	ret

recargarBuffer:
	;Lee del archivo 1001 bytes mas y los carga en bufferGral
	;reseteando la posBuffer a la primera posicion del BufferGral
	;y fin en la siguiente posicion a la ultima insertada en bufferGral.
	;Si en el archivo quedan menos de 1001 bytes,
	;carga todos los bytes que quedan.

	mov EAX,3		;sys_Read
	mov EBX,[pArchivo]	;EBX<-descriptor del Archivo
	mov ECX,bufferGral	;Buffer <- lectura del Archivo
	mov EDX,largoLinea		;leemos 1001 bytes del Archivo
	int 80h

	;Lei archivo, tengo que testear que no se produjeron errores
	test EAX,EAX		;mirar que retorna
	js salir_Error_Input	;si se produjoun error salimos

	;En EAX esta la cantidad de  bytes que lei del archivo
	;setea fin
	add EAX,bufferGral		;EAX <- EAX+BufferGral
	mov [fin],EAX			;fin <- EAX
	mov EAX,bufferGral		;
	mov [posBuffer],EAX		;resetear la posicion de posBuffer

	ret



imprimir:
	;Imprime en "salida" el texto cargado en ECX
	;con el tamaño EDX
	;asumo inicializado el DeviceDescriptor en salida

	;cargo en la pila los valores a modificar
	push EAX	;me guardo el valor de EAX
	push EBX	;me guardo el valor de EBX

	;imprime el texto
	mov EAX,4	;sys_write
	mov EBX,[salida];Descriptor de Archivo
	int 80h		;syscall

	;restauro los valores de los registros que modifique
	pop EBX		;recupero EBX
	pop EAX		;recupero EAX

	ret

imprimirSalto:
	;imprime un salto de linea en "salida"
	;Modifica el estado de EAX,EBX,ECX, y EDX

	mov EAX,4	;sys_write
	mov EBX,[salida];Descriptor de Archivo
	mov ECX,salto	;imprime un salto
	mov EDX,1	;imprime 1 byte
	int 80h
	
	ret
salir_ConExito:
	;Termina la ejecucion del programa con Error=0
	mov EAX,1	;sys_exit
	mov EBX,0	;error=0
	int 80h

salir_Error_Input:
	;termina el programa por un Error en
	;el archivo de Entrada.
	mov EAX,1	;sys_exit
	mov EBX,1	;error =1
	int 80h
salir_Error_Output:
	;termina el programa por un Error en
	;el archivo de Salida.
	mov EAX,1	;sys_exit
	mov EBX,2	;error=2
	int 80h
salir_Error_Other:
	;termina el programa por un Error.

	mov EAX,1	;sys_exit
	mov EBX,3	;error=3
	int 80h
imprimirAyuda:
	;Imprime un mensaje de ayuda para el usuario
	mov ECX,mensaje_help	;cargo el mensaje a mostrar
	mov EDX,largo_mhelp	;cargo el largo del mensaje
	call imprimir		;imprimo el mensaje
	
	jmp salir_ConExito	

imprimirSaltoDebug
	push EAX
	push EBX
	push ECX
	push EDX
	call imprimirSalto
	pop EDX
	pop ECX
	pop EBX
	pop EAX
	ret
;....................................................................................
	;Codigo de ITOA
itoa:
	;Convierte un entero a string

	;Parámetros
	;	EAX - Entero
	;	EBX - Puntero a un buffer
	;Retorno
	;	EAX - Cantidad de caracteres creados


	;voy a usar una variable local

	push EBP	;Guardar la base de la pila
	mov EBP, ESP	;Nueva base de la pila

	;reservo espacio para mis variables
	push 10		;guardo un 10, en la direccion [EBP-4]
	push EBX	;necesito una copia del puntero, [EBP-8]

	;EAX tiene el entero

	;inicializo un contador de caracteres
	mov ECX,0


itoa_siguiente:

	mov EDX,0		; cargo 0 en EDX

	idiv DWORD[EBP-4]	; divido lo que hay en EDX:EAX por 10

	;en EAX quedo el cociente
	;ahora en EDX esta el resto, o sea el digito

	;convierto el digito a char
	add EDX,30h	;Le sumo 48 al digito (ASCII)
	push EDX 	;guardo el digito en la pila
	inc ECX		;incremento el contador

	cmp EAX,0 	;EAX es 0?
	jnz itoa_siguiente

	;ahora ya tengo todos los char en la pila

	mov EAX,ECX 	;guardo el valor de retorno


itoa_guardar:

	pop EDX 	;recupero el siguiente char
	mov [EBX],DL	;guardo el char en el buffer (operacion delicada- 4 bytes a 1 byte) 

	inc EBX 	;avanzo al siguiente char del buffer
	dec ECX 	;decremento el contador
	cmp ECX,0	;el contador es 0?
	jnz itoa_guardar   ;siguiente char

	mov EBX,[EBP-8]	;recupero el puntero al buffer
	mov ESP,EBP	;recupero el tope original
	pop EBP		;recupero la base original
	ret		;retorno

	;FIN DE CODIGO ITOA
;.................................................................................... 

	;INICIO CODIGO BUSCAR_CADENA
	;Determina si una cadena esta contenida en otra
	;Parámetros
	;	EAX -Cadena  A
	;	EBX - Patron a Buscar
	;Retorno
	;	EAX - un 1 si A contiene el patron,0 sino



buscar_cadena:

	;Esta funcion recibe dos cadenas como parametros,
	;la cadena A en EAX  y la cadena B en  EBX.
	;Retorna 1 en EAX si la cadena B
	;esta contenida en la cadena A,0 de lo contrario.

	;Voy a necesitar una variable local que la voy a sacar de la pila

	push ECX	;Guardo copia de ECX
	push EBP	;Guardo copia de la base de pila
	mov EBP, ESP	;la base actual apunta al tope

	push EBX 	;Guardo copia del puntero al primer lugar de la cadena B(en EBP-4)

compararSiguiente:
	cmp BYTE [EBX],0 ;si termina en 0 quiere decir que toda la cadena B estaba contenida
	je ret_Busc_EAX_1	 ;entonces retornamos con un 1 en EAX,

	cmp BYTE [EAX],0	;leimos toda la cadena A y no terminamos de encontrar la B
	je ret_Busc_EAX_0	;entonces retornamos con un 0 en EAX

	mov CL, BYTE [EAX] 	; recupero el sig char de la cadena A
	cmp CL, BYTE[EBX] 	; comparo los caracteres de ambas cadenas
	je siguienteChar	; si son = paso a procesar el siguiente char

	;Los caracteres leidos de A y B son distintos

	cmp EBX, [EBP-4] 	; si los caracteres son estoy en el primer char de la cadena B?
	jne resetEBX		; si ya avance en la cadena B,vuelvo a comparar desde el comienzo

	inc EAX 		; avanzo al siguiente char de la cadena A
	jmp compararSiguiente 	; vuelvo a Comparar

resetEBX:
	;ubica a EBX en la primera posicion de la cadena B
	mov EBX,[EBP-4] 	; restauro el puntero al patron
	jmp compararSiguiente 	;vuelvo a Comparar

siguienteChar:
	;Avanza en la cadena A y en la B
	inc EAX		;Avanzo al siguiente char de la cadena A
	inc EBX		;Avanzo al siguiente char de la cadena B
	jmp compararSiguiente 	;vuelvo a Comparar

ret_Busc_EAX_1:
	;Retornar con un 1 en EAX(verdadero)
	mov EAX,1	;carga en EAX un 1
	jmp ret_buscar_cadena

ret_Busc_EAX_0:
	;Retornar con un 0 en EAX(falso)
	mov EAX,0	;carga en EAX un 0

ret_buscar_cadena:
	;Restaura el estado de la pila previo a la ejecucion de buscar_cadena
	mov ESP, EBP		;Descarto la variable local, al tope le pongo
				; lo que tiene la base
	pop EBP			; restauro la base de la pila
	pop ECX 		; restauro el registro ECX
	ret

	;FIN CODIGO BUSCAR_CADENA
;.................................................................................... 
	;INICIO CODIGO COMPARAR
	;Determina si una cadena es igual a otra
	;Parámetros
	;	EAX - Cadena  A
	;	EBX - Cadena B
	;Retorno
	;	EAX - un 1 si A es igual a B,0 sino

comparar_cadena:

	;Esta funcion recibe dos cadenas como parametros,
	;la cadena A en EAX  y la cadena B en  EBX.
	;Retorna un 1 en EAX si la cadena B es igual a la cadena A
	;Sino retorna un 0

	; voy a necesitar una variable local que la voy a sacar de la pila
	push ECX	;Guardo copia de ECX
	push EBP	;Guardo copia de la base de pila
	mov EBP, ESP	;la base actual apunta al tope
	push EBX	;me guardo el valor de EBX

CompSig:
	cmp BYTE [EAX],0 ;si termina en 0 termino de analizar la 1ra cadena
	je terminoA	 ;

	;No termino de leer A

	cmp BYTE [EBX],0	;termino de leer B?
	je ret_Comp_EAX_0	;termino de leer B antes que A,son distintos

	;No termino de leer ni A ni B

	mov CL, BYTE [EAX] 	; recupero el sig char de la 1ra cadena
	cmp CL, BYTE[EBX] 	; comparo los caracteres de abmas cadenas
	je siguientechar	; si son = paso a procesar el siguiente char

	jmp ret_Comp_EAX_0	; los caracteres leidos de A y B son distintos
				; Entonces A y B son distintos.

terminoA:
	;Se termino de analizar la cadena A
	;si tambien se termino la B,son iguales
	;sino, son diferentes

	cmp BYTE [EBX],0	;comparo si terminaron los 2
	je ret_Comp_EAX_1	;terminaron las 2 cadenas a la vez
	jmp ret_Comp_EAX_0	;termino A antes que B

siguientechar:
	;Avanza en la cadena A y en la B
	inc EAX		;Avanzo al siguiente char de la cadena A
	inc EBX		;Avanzo al siguiente char de la cadena B
	jmp CompSig 	; vuelvo a comparar

ret_Comp_EAX_1:
	;Retornar con un 1 en EAX(verdadero)
	mov EAX,1
	jmp  limpiarPilaComp
ret_Comp_EAX_0:
	;Retornar con un 0 en EAX(falso)
	mov EAX,0

limpiarPilaComp:
	;Restaura el estado de la pila previo a la ejecucion de buscar_cadena
	pop EBX		 	;restauro el valor de EBX
	mov ESP, EBP		;Descarto la variable local, al tope le pongo
				; lo que tiene la base
	pop EBP			; restauro la base de la pila
	pop ECX 		; restauro el registro ECX
	ret

	; FIN CODIGO COMPARAR CADENA
;.................................................................................... 
