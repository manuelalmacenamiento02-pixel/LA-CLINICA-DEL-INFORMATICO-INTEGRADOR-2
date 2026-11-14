"""Genera diagramas UML vectoriales del proyecto. Python 3, sin dependencias para SVG."""
from pathlib import Path
from html import escape
import sys
import math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs' / 'diagramas'
OUT.mkdir(parents=True, exist_ok=True)
parts = []

def text(x, y, lines, size=16, anchor='middle', color='#172b43'):
    if isinstance(lines, str): lines = [lines]
    for i, line in enumerate(lines):
        parts.append(f'<text x="{x}" y="{y+i*(size+7)}" font-family="Arial, sans-serif" font-size="{size}" text-anchor="{anchor}" fill="{color}">{escape(line)}</text>')

def rect(x,y,w,h,fill='#ffffff',stroke='#29445e'):
    parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{stroke}" stroke-width="1.6"/>')

def line(points, dashed=False, arrow=False):
    for (x,y),(u,v) in zip(points,points[1:]):
        length=math.hypot(u-x,v-y)
        if not length: continue
        for offset in (range(0, math.ceil(length), 12) if dashed else [0]):
            end=min(offset+7,length) if dashed else length
            a,b=offset/length,end/length
            parts.append(f'<path d="M{x+(u-x)*a},{y+(v-y)*a} L{x+(u-x)*b},{y+(v-y)*b}" fill="none" stroke="#29445e" stroke-width="1.6"/>')
    if arrow:
        (x,y),(u,v)=points[-2:]; angle=math.atan2(v-y,u-x)
        for delta in [-0.45,0.45]:
            a=u-11*math.cos(angle+delta); b=v-11*math.sin(angle+delta)
            parts.append(f'<path d="M{a},{b} L{u},{v}" fill="none" stroke="#29445e" stroke-width="1.6"/>')

def component(x,y,w,h,title,details):
    rect(x,y,w,h,'#edf5fc')
    rect(x-9,y+18,20,12); rect(x-9,y+40,20,12)
    text(x+w/2,y+28,title,17)
    text(x+w/2,y+55,details,13)

def interface(x,y,label,provider_x):
    line([(provider_x,y),(x+8,y)])
    parts.append(f'<circle cx="{x}" cy="{y}" r="8" fill="white" stroke="#29445e" stroke-width="1.6"/>')
    text(x,y-17,label,13)

def node(x,y,w,h,title,subtitle):
    parts.append(f'<path d="M{x},{y} l14,-12 h{w} v{h} l-14,12 M{x+w},{y} l14,-12 M{x},{y} h{w} v{h} h-{w} Z" fill="#f4f7fa" stroke="#29445e" stroke-width="1.6"/>')
    text(x+w/2,y+25,title,15)
    text(x+w/2,y+49,subtitle,16)

def start(title,subtitle):
    parts.clear()
    parts.append('<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="940" viewBox="0 0 1280 940"><defs><marker id="arrow" markerWidth="12" markerHeight="10" refX="11" refY="5" orient="auto"><path d="M1,1 L11,5 L1,9" fill="none" stroke="#29445e" stroke-width="1.4"/></marker></defs><rect width="1280" height="940" fill="white"/>')
    text(640,40,title,26); text(640,70,subtitle,15)

def save(name):
    (OUT / (name+'.svg')).write_text('\n'.join(parts)+ '\n</svg>', encoding='utf-8')

start('Diagrama de componentes', 'La Clínica del Informático | Componentes lógicos de la implementación actual')
rect(28,100,395,590,'#fafcfe'); text(225,129,'Presentación · Angular',19)
rect(445,100,360,590,'#fafcfe'); text(625,129,'Aplicación · Spring Boot',19)
rect(827,100,425,590,'#fafcfe'); text(1040,129,'Persistencia',19)
component(60,160,330,145,'Interfaz web',['Login y navegación · Dashboard','Clientes · Equipos · Historial de equipo','Usuarios y permisos','Componentes Angular y guards'])
component(60,360,330,125,'Servicios de presentación',['AuthService · ClientService','EquipmentService · UserService','PermissionsService'])
component(60,550,330,100,'Estado y cliente HTTP',['ApiStore · HttpClient','Sesión, datos y solicitudes /api'])
line([(225,305),(225,360)],True,True)
line([(225,485),(225,550)],True,True)
component(495,200,275,110,'API de la clínica',['ClinicController','Autenticación, clientes, equipos,','usuarios, permisos y bootstrap'])
interface(463,255,'API REST',495)
line([(390,600),(430,600),(430,255),(455,255)],True,True)
component(495,365,275,95,'Control de acceso',['AccessConfig','Sesiones y permisos'])
line([(632,365),(632,310)],True,True)
component(495,530,275,105,'Soporte de la API',['HealthController · ApiErrors','Salud y tratamiento de errores','BootstrapAdmin: usuario inicial'])
component(890,200,330,115,'Acceso a datos',['ClinicRepository · JdbcTemplate','Consultas SQL y eventos del sistema'])
interface(850,255,'Datos',890)
line([(770,255),(842,255)],True,True)
line([(770,410),(815,410),(815,275),(842,255)],True,True)
line([(770,582),(815,582),(815,275)],True,True)
component(890,385,330,100,'Migración del esquema',['Flyway','V1 · V2 · V3 (archivos SQL)'])
component(890,550,330,100,'Persistencia PostgreSQL',['Base de datos clinica_informatica','Tablas, restricciones e índices'])
interface(850,600,'SQL / JDBC',890)
line([(1055,315),(1240,315),(1240,675),(850,675),(850,608)],True,True)
line([(1055,485),(1055,550)],True,True)
text(640,732,'Lectura del diagrama',18)
text(640,760,['Cada caja representa un componente lógico que agrupa clases y ofrece responsabilidades relacionadas.',
 'Las flechas discontinuas apuntan al proveedor del servicio; los círculos representan interfaces proporcionadas.',
 'API REST está sujeta a AccessConfig. BootstrapAdmin utiliza el repositorio; HealthController no accede a datos.'],14)
text(640,846,['Alcance: el historial usa EquipmentService y los datos cargados; no hay una API de historial independiente.',
 'Las pantallas de órdenes, IA, seguimiento e indicadores siguen como marcadores; /bootstrap sí consulta órdenes asignadas.',
 'Guía de notación: S10_s1_Material.pdf, páginas 12–18.'],13)
save('diagrama-componentes')

start('Diagrama de despliegue','La Clínica del Informático | Topología local de desarrollo configurada en el proyecto')
node(45,115,1175,650,'«device»','Equipo local Windows')
node(90,205,470,180,'«executionEnvironment»','Navegador web')
rect(125,275,400,75,'#edf5fc'); text(325,300,['«artifact» Aplicación Angular','HTML, CSS y JavaScript ejecutados en el cliente'],14)
node(680,205,470,180,'«executionEnvironment»','Node.js / Angular CLI')
rect(715,275,400,75,'#edf5fc'); text(915,300,['ng serve · localhost:4200','Sirve la aplicación y aplica proxy.conf.json'],14)
node(680,495,470,185,'«executionEnvironment»','JVM · Java 25 / Spring Boot')
rect(715,565,400,80,'#edf5fc'); text(915,590,['«artifact» clinica-api-0.0.1-SNAPSHOT.jar','API REST · servidor embebido · puerto 8080','Flyway y db/migration/V1…V3.sql'],13)
node(90,495,470,185,'«executionEnvironment»','PostgreSQL · localhost:5432')
rect(125,565,400,80,'#edf5fc'); text(325,590,['«artifact» Base de datos clinica_informatica','Esquema y datos persistentes'],14)
line([(560,295),(680,295)]); text(620,254,['HTTP','4200'],13)
line([(915,385),(915,495)]); text(938,426,['HTTP /api · 8080','Proxy de desarrollo'],13,anchor='start')
line([(560,590),(680,590)]); text(620,548,['JDBC / TCP','5432'],13)
text(640,719,'Las conexiones se realizan en el mismo equipo mediante localhost (interfaz de loopback).',15)
text(640,811,['Los cubos representan nodos o entornos de ejecución; los artefactos se ubican dentro del entorno que los ejecuta.',
 'Las líneas continuas representan caminos de comunicación, según el material del profesor (páginas 20–23).',
 'El nombre del JAR corresponde al empaquetado Maven; en desarrollo también puede ejecutarse con spring-boot:run.',
 'Flyway se ejecuta dentro del backend al iniciar. Esta vista no presupone servidores físicos separados.'],14)
save('diagrama-despliegue')

start('Arquitectura de aplicaciones','La Clínica del Informático | Organización del sistema en tres capas')
text(640,110,'Usuarios: administrador · personal de atención · técnico',17)
line([(640,125),(640,155)],arrow=True)
rect(130,155,1020,225,'#edf5fc')
text(640,185,'1. PRESENTACIÓN · Angular',21)
rect(160,210,440,110)
text(380,237,['Pantallas del sistema','Inicio de sesión · Panel principal','Clientes · Equipos · Usuarios'],17)
rect(670,210,450,110)
text(895,237,['Servicios de la interfaz','Organizan los datos de las pantallas','y envían las solicitudes al servidor'],17)
line([(600,265),(670,265)],arrow=True)
text(640,352,'El usuario accede al sistema desde el navegador.',17)
line([(640,380),(640,435)],arrow=True)
text(655,413,'Solicitudes y respuestas (HTTP)',16,anchor='start')
rect(130,435,1020,245,'#f0f7f3')
text(640,466,'2. APLICACIÓN · Spring Boot',21)
rect(160,493,265,112)
text(292,520,['Control de acceso','Verifica el inicio de sesión','y los permisos del usuario'],16)
rect(470,493,315,112)
text(627,520,['Procesamiento','Gestiona clientes, equipos,','usuarios y permisos'],16)
rect(830,493,290,112)
text(975,520,['Acceso a datos','Consulta y actualiza','la base de datos'],16)
line([(425,549),(470,549)],arrow=True)
line([(785,549),(830,549)],arrow=True)
text(640,645,'El servidor recibe las solicitudes y realiza las operaciones del sistema.',17)
line([(975,605),(975,713)],arrow=True)
text(1000,700,'Consultas SQL',15,anchor='start')
rect(130,713,1020,115,'#fff7e9')
text(640,745,'3. DATOS · PostgreSQL',21)
text(640,776,['Guarda la información del sistema','Clientes · Equipos · Usuarios · Roles y permisos · Órdenes'],17)
text(640,875,'El usuario usa las pantallas, el servidor procesa las operaciones y la base de datos guarda la información.',17)
save('arquitectura-aplicaciones')

# Exportaciones adicionales cuando PyMuPDF está disponible en el directorio local.
sys.path.insert(0, str(ROOT / '.local' / 'diagram-tools'))
try:
    import pymupdf
except ImportError:
    print('SVG generados. Para PDF/PNG se requiere PyMuPDF en .local/diagram-tools.')
else:
    combined=pymupdf.open()
    for name in ['arquitectura-aplicaciones','diagrama-componentes','diagrama-despliegue']:
        svg=pymupdf.open(OUT / (name+'.svg'))
        pdf=pymupdf.open('pdf',svg.convert_to_pdf())
        pdf.save(OUT / (name+'.pdf'))
        pdf[0].get_pixmap(matrix=pymupdf.Matrix(1.6,1.6)).save(OUT / (name+'.png'))
        combined.insert_pdf(pdf)
    combined.save(OUT / 'diagramas-uml-clinica.pdf')
    print('SVG, PNG y PDF generados en',OUT)
