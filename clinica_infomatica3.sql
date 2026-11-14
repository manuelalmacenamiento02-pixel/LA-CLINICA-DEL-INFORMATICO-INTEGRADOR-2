--
-- PostgreSQL database dump
--

\restrict GMYNRfHbwSaW6GEJhbfC8UHNumvQ0iTFWTHJFoxIJHbaHVHWhrP9aR8KyKxpnoj

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

-- Started on 2026-11-07 15:05:46

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 243 (class 1255 OID 17463)
-- Name: touch_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;


ALTER FUNCTION public.touch_updated_at() OWNER TO postgres;

--
-- TOC entry 240 (class 1255 OID 17455)
-- Name: validate_order_owner(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_order_owner() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM equipment WHERE id = NEW.equipment_id AND client_id = NEW.client_id) THEN
  RAISE EXCEPTION 'El equipo no pertenece al cliente de la orden' USING ERRCODE = '23514';
 END IF;
 RETURN NEW;
END $$;


ALTER FUNCTION public.validate_order_owner() OWNER TO postgres;

--
-- TOC entry 242 (class 1255 OID 17461)
-- Name: validate_status_transition(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_status_transition() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF NEW.status_code <> OLD.status_code AND NOT EXISTS (
  SELECT 1 FROM order_status_transitions WHERE from_status = OLD.status_code AND to_status = NEW.status_code
 ) THEN
  RAISE EXCEPTION 'Transición de estado no permitida' USING ERRCODE = '23514';
 END IF;
 RETURN NEW;
END $$;


ALTER FUNCTION public.validate_status_transition() OWNER TO postgres;

--
-- TOC entry 241 (class 1255 OID 17457)
-- Name: validate_technician(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_technician() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM users WHERE id = NEW.technician_id AND role_code = 'TÉCNICO' AND active) THEN
  RAISE EXCEPTION 'Se requiere un técnico activo' USING ERRCODE = '23514';
 END IF;
 RETURN NEW;
END $$;


ALTER FUNCTION public.validate_technician() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 233 (class 1259 OID 17309)
-- Name: ai_prediagnoses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ai_prediagnoses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    requested_by uuid NOT NULL,
    provider character varying(40) DEFAULT 'gemini'::character varying NOT NULL,
    model character varying(120) NOT NULL,
    input_data jsonb NOT NULL,
    generated_diagnosis text,
    status character varying(20) DEFAULT 'PENDIENTE'::character varying NOT NULL,
    error_message text,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    result_data jsonb,
    CONSTRAINT ai_prediagnoses_check CHECK (((((status)::text = 'PENDIENTE'::text) AND (completed_at IS NULL)) OR (((status)::text = 'GENERADO'::text) AND (completed_at IS NOT NULL) AND (generated_diagnosis IS NOT NULL) AND (btrim(generated_diagnosis) <> ''::text)) OR (((status)::text = 'ERROR'::text) AND (completed_at IS NOT NULL) AND (error_message IS NOT NULL) AND (btrim(error_message) <> ''::text)))),
    CONSTRAINT ai_prediagnoses_input_data_check CHECK ((jsonb_typeof(input_data) = 'object'::text)),
    CONSTRAINT ai_prediagnoses_status_check CHECK (((status)::text = ANY ((ARRAY['PENDIENTE'::character varying, 'GENERADO'::character varying, 'ERROR'::character varying])::text[])))
);


ALTER TABLE public.ai_prediagnoses OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 17343)
-- Name: ai_validations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ai_validations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    prediagnosis_id uuid NOT NULL,
    technician_id uuid NOT NULL,
    decision character varying(20) NOT NULL,
    final_diagnosis text,
    observations text DEFAULT ''::text NOT NULL,
    validated_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_data jsonb,
    CONSTRAINT ai_validations_decision_check CHECK (((decision)::text = ANY ((ARRAY['ACEPTADO'::character varying, 'MODIFICADO'::character varying, 'DESCARTADO'::character varying, 'RECHAZADO'::character varying])::text[]))),
    CONSTRAINT ai_validations_final_diagnosis_check CHECK ((btrim(final_diagnosis) <> ''::text))
);


ALTER TABLE public.ai_validations OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 17399)
-- Name: backup_runs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.backup_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    requested_by uuid,
    status character varying(20) DEFAULT 'EN_PROCESO'::character varying NOT NULL,
    file_path text,
    checksum_sha256 character varying(64),
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    error_message text,
    CONSTRAINT backup_runs_check CHECK (((finished_at IS NULL) OR (finished_at >= started_at))),
    CONSTRAINT backup_runs_check1 CHECK (((((status)::text = 'EN_PROCESO'::text) AND (finished_at IS NULL)) OR (((status)::text = 'COMPLETADO'::text) AND (finished_at IS NOT NULL) AND (file_path IS NOT NULL) AND (checksum_sha256 IS NOT NULL) AND ((checksum_sha256)::text ~ '^[a-f0-9]{64}$'::text)) OR (((status)::text = 'ERROR'::text) AND (finished_at IS NOT NULL) AND (error_message IS NOT NULL)))),
    CONSTRAINT backup_runs_status_check CHECK (((status)::text = ANY ((ARRAY['EN_PROCESO'::character varying, 'COMPLETADO'::character varying, 'ERROR'::character varying])::text[])))
);


ALTER TABLE public.backup_runs OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 17043)
-- Name: clients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_type character varying(10) NOT NULL,
    document_number character varying(25) NOT NULL,
    first_name character varying(150) NOT NULL,
    last_name character varying(100) DEFAULT ''::character varying NOT NULL,
    phone character varying(30) NOT NULL,
    email character varying(254) DEFAULT ''::character varying NOT NULL,
    address character varying(300) DEFAULT ''::character varying NOT NULL,
    observations text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT clients_check CHECK ((((document_type)::text = 'RUC'::text) OR (btrim((last_name)::text) <> ''::text))),
    CONSTRAINT clients_check1 CHECK (((((document_type)::text = 'DNI'::text) AND ((document_number)::text ~ '^[0-9]{8}$'::text)) OR (((document_type)::text = 'RUC'::text) AND ((document_number)::text ~ '^[0-9]{11}$'::text)) OR (((document_type)::text = 'CE'::text) AND ((document_number)::text ~ '^[a-zA-Z0-9-]{5,20}$'::text)) OR (((document_type)::text = 'Otro'::text) AND ((length((document_number)::text) >= 1) AND (length((document_number)::text) <= 25))))),
    CONSTRAINT clients_document_number_check CHECK (((document_number)::text = btrim((document_number)::text))),
    CONSTRAINT clients_document_type_check CHECK (((document_type)::text = ANY ((ARRAY['DNI'::character varying, 'RUC'::character varying, 'CE'::character varying, 'Otro'::character varying])::text[]))),
    CONSTRAINT clients_email_check CHECK ((((email)::text = ''::text) OR ((email)::text ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'::text))),
    CONSTRAINT clients_first_name_check CHECK ((btrim((first_name)::text) <> ''::text))
);


ALTER TABLE public.clients OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 17076)
-- Name: equipment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.equipment (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_id uuid NOT NULL,
    type character varying(30) NOT NULL,
    brand character varying(100) NOT NULL,
    model character varying(100) NOT NULL,
    serial_number character varying(100) DEFAULT ''::character varying NOT NULL,
    characteristics text DEFAULT ''::text NOT NULL,
    accessories text DEFAULT ''::text NOT NULL,
    observations text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT equipment_brand_check CHECK ((btrim((brand)::text) <> ''::text)),
    CONSTRAINT equipment_check CHECK ((((type)::text = 'Otro'::text) OR (btrim((serial_number)::text) <> ''::text))),
    CONSTRAINT equipment_model_check CHECK ((btrim((model)::text) <> ''::text)),
    CONSTRAINT equipment_serial_number_check CHECK (((serial_number)::text = btrim((serial_number)::text))),
    CONSTRAINT equipment_type_check CHECK (((type)::text = ANY ((ARRAY['Laptop'::character varying, 'PC'::character varying, 'Impresora'::character varying, 'Monitor'::character varying, 'Tablet'::character varying, 'Otro'::character varying])::text[])))
);


ALTER TABLE public.equipment OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16965)
-- Name: flyway_schema_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.flyway_schema_history (
    installed_rank integer NOT NULL,
    version character varying(50),
    description character varying(200) NOT NULL,
    type character varying(20) NOT NULL,
    script character varying(1000) NOT NULL,
    checksum integer,
    installed_by character varying(100) NOT NULL,
    installed_on timestamp without time zone DEFAULT now() NOT NULL,
    execution_time integer NOT NULL,
    success boolean NOT NULL
);


ALTER TABLE public.flyway_schema_history OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 17421)
-- Name: monitoring_checks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.monitoring_checks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    component character varying(80) NOT NULL,
    status character varying(10) NOT NULL,
    response_time_ms integer,
    message text DEFAULT ''::text NOT NULL,
    checked_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT monitoring_checks_response_time_ms_check CHECK ((response_time_ms >= 0)),
    CONSTRAINT monitoring_checks_status_check CHECK (((status)::text = ANY ((ARRAY['OK'::character varying, 'ALERTA'::character varying, 'ERROR'::character varying])::text[])))
);


ALTER TABLE public.monitoring_checks OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 17235)
-- Name: order_status_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.order_status_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    from_status character varying(30),
    to_status character varying(30) NOT NULL,
    changed_by uuid NOT NULL,
    reason text DEFAULT ''::text NOT NULL,
    changed_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.order_status_history OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 17124)
-- Name: order_status_transitions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.order_status_transitions (
    from_status character varying(30) NOT NULL,
    to_status character varying(30) NOT NULL,
    CONSTRAINT order_status_transitions_check CHECK (((from_status)::text <> (to_status)::text))
);


ALTER TABLE public.order_status_transitions OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 17113)
-- Name: order_statuses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.order_statuses (
    code character varying(30) NOT NULL,
    name character varying(80) NOT NULL,
    terminal boolean DEFAULT false NOT NULL
);


ALTER TABLE public.order_statuses OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16991)
-- Name: permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.permissions (
    code character varying(50) NOT NULL,
    description character varying(120) NOT NULL
);


ALTER TABLE public.permissions OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 16998)
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.role_permissions (
    role_code character varying(40) NOT NULL,
    permission_code character varying(50) NOT NULL
);


ALTER TABLE public.role_permissions OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 16982)
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    code character varying(40) NOT NULL,
    name character varying(80) NOT NULL
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 17142)
-- Name: service_order_number_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.service_order_number_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.service_order_number_seq OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 17143)
-- Name: service_orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.service_orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    number bigint DEFAULT nextval('public.service_order_number_seq'::regclass) NOT NULL,
    equipment_id uuid NOT NULL,
    client_id uuid NOT NULL,
    received_by uuid NOT NULL,
    reported_problem text NOT NULL,
    intake_condition text DEFAULT ''::text NOT NULL,
    intake_accessories text DEFAULT ''::text NOT NULL,
    status_code character varying(30) DEFAULT 'PENDIENTE'::character varying NOT NULL,
    priority character varying(10) DEFAULT 'NORMAL'::character varying NOT NULL,
    estimated_delivery timestamp with time zone,
    closed_at timestamp with time zone,
    closure_summary text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    received_at date DEFAULT CURRENT_DATE NOT NULL,
    finalized_at timestamp with time zone,
    finalized_by uuid,
    CONSTRAINT service_orders_check CHECK (((estimated_delivery IS NULL) OR (estimated_delivery >= created_at))),
    CONSTRAINT service_orders_check1 CHECK (((((status_code)::text = ANY ((ARRAY['CERRADA'::character varying, 'CANCELADA'::character varying])::text[])) AND (closed_at IS NOT NULL) AND (closure_summary IS NOT NULL) AND (btrim(closure_summary) <> ''::text)) OR (((status_code)::text <> ALL ((ARRAY['CERRADA'::character varying, 'CANCELADA'::character varying])::text[])) AND (closed_at IS NULL)))),
    CONSTRAINT service_orders_finalized_metadata CHECK (((((status_code)::text = 'FINALIZADA'::text) AND (finalized_at IS NOT NULL) AND (finalized_by IS NOT NULL)) OR (((status_code)::text <> 'FINALIZADA'::text) AND (finalized_at IS NULL) AND (finalized_by IS NULL)))),
    CONSTRAINT service_orders_priority_check CHECK (((priority)::text = ANY ((ARRAY['BAJA'::character varying, 'NORMAL'::character varying, 'ALTA'::character varying, 'URGENTE'::character varying])::text[]))),
    CONSTRAINT service_orders_reported_problem_check CHECK ((btrim(reported_problem) <> ''::text))
);


ALTER TABLE public.service_orders OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 17470)
-- Name: service_indicators; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.service_indicators AS
 SELECT status_code,
    count(*) AS total,
    avg((EXTRACT(epoch FROM (closed_at - created_at)) / (3600)::numeric)) FILTER (WHERE (closed_at IS NOT NULL)) AS average_duration_hours
   FROM public.service_orders
  GROUP BY status_code;


ALTER VIEW public.service_indicators OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 17375)
-- Name: system_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.system_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_id uuid,
    event_type character varying(80) NOT NULL,
    entity_type character varying(80) NOT NULL,
    entity_id uuid,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    result character varying(10) DEFAULT 'SUCCESS'::character varying NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    CONSTRAINT system_events_details_check CHECK ((jsonb_typeof(details) = 'object'::text)),
    CONSTRAINT system_events_result_check CHECK (((result)::text = ANY ((ARRAY['SUCCESS'::character varying, 'FAILED'::character varying])::text[])))
);


ALTER TABLE public.system_events OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 17439)
-- Name: system_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.system_settings (
    key character varying(80) NOT NULL,
    value jsonb NOT NULL,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.system_settings OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 17273)
-- Name: technical_attentions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.technical_attentions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    technician_id uuid NOT NULL,
    diagnosis text NOT NULL,
    actions_performed text NOT NULL,
    recommendations text DEFAULT ''::text NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    performed_tests text DEFAULT ''::text NOT NULL,
    parts_used text DEFAULT ''::text NOT NULL,
    observations text DEFAULT ''::text NOT NULL,
    result_summary text DEFAULT ''::text NOT NULL,
    updated_by uuid,
    CONSTRAINT technical_attentions_actions_performed_check CHECK ((btrim(actions_performed) <> ''::text)),
    CONSTRAINT technical_attentions_check CHECK (((finished_at IS NULL) OR (finished_at >= started_at))),
    CONSTRAINT technical_attentions_diagnosis_check CHECK ((btrim(diagnosis) <> ''::text))
);


ALTER TABLE public.technical_attentions OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 17200)
-- Name: technician_assignments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.technician_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    technician_id uuid NOT NULL,
    assigned_by uuid NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL,
    ended_at timestamp with time zone,
    notes text DEFAULT ''::text NOT NULL,
    CONSTRAINT technician_assignments_check CHECK (((ended_at IS NULL) OR (ended_at >= assigned_at)))
);


ALTER TABLE public.technician_assignments OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 17015)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    username character varying(80) NOT NULL,
    password_hash character varying(100) NOT NULL,
    role_code character varying(40) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT users_first_name_check CHECK ((btrim((first_name)::text) <> ''::text)),
    CONSTRAINT users_last_name_check CHECK ((btrim((last_name)::text) <> ''::text)),
    CONSTRAINT users_username_check CHECK (((btrim((username)::text) <> ''::text) AND ((username)::text = btrim((username)::text))))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 5311 (class 0 OID 17309)
-- Dependencies: 233
-- Data for Name: ai_prediagnoses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ai_prediagnoses (id, order_id, requested_by, provider, model, input_data, generated_diagnosis, status, error_message, requested_at, completed_at, result_data) FROM stdin;
05c9d944-2f16-41e0-babf-37a68fbf67ea	4eac7b12-84dc-4176-bc51-2e1807855335	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	gemini	gemini-3.8-flash	{"brand": "lenovo", "model": "g310", "observations": "se registra la laptop con pantalla azul", "equipmentType": "Laptop", "reportedProblem": "Error con el sistema, pantallazo azul con codigo de disco dañando", "additionalSymptoms": "", "initialObservations": "se registra la laptop con pantalla azul", "technicalCharacteristics": ""}	{\n  "classification": "Falla lógica o física de almacenamiento / Inestabilidad de sistema operativo (BSOD)",\n  "suggestedPriority": "ALTA",\n  "possibleCauses": [\n    "Degradación física o presencia de sectores defectuosos en la unidad de almacenamiento (HDD/SSD)",\n    "Corrupción del sistema de archivos o partición de arranque del sistema operativo",\n    "Falso contacto o degradación en el conector SATA/interfaz de la unidad",\n    "Inestabilidad o fallas en la memoria RAM que generen errores de paginación o lectura",\n    "Controladores de almacenamiento incompatibles o dañados tras actualización"\n  ],\n  "recommendedTests": [\n    "Ejecutar diagnóstico de salud SMART mediante un entorno Live USB sin iniciar el sistema operativo",\n    "Realizar prueba de diagnóstico de hardware Lenovo (Lenovo Diagnostics) mediante la tecla de función al arranque",\n    "Verificar la integridad del sistema de archivos mediante chkdsk en modo solo lectura desde la consola de recuperación",\n    "Ejecutar test de diagnóstico de memoria RAM (MemTest86 o diagnóstico integrado) para descartar fallas de memoria",\n    "Inspección física y reconexión segura de la unidad de almacenamiento para descartar falso contacto"\n  ],\n  "recommendations": [\n    "Priorizar el respaldo inmediato de información crítica antes de someter la unidad a pruebas de estrés o escritura intensiva",\n    "Evitar reintentos de arranque repetidos que puedan acelerar el daño en un disco mecánico con sectores dañados",\n    "Utilizar un entorno de arranque externo (PE/Live USB) para verificar si la unidad es detectable y legible",\n    "Evaluar el reemplazo por una unidad de estado sólido (SSD) en caso de confirmarse daño en el almacenamiento"\n  ],\n  "warnings": [\n    "No se especifica el código de error BSOD exacto ni el tipo de unidad instalada (HDD o SSD)",\n    "Intentar reparar sectores dañados con herramientas de escritura agresiva puede derivar en pérdida irreversible de datos",\n    "La manipulación interna de la laptop requiere desconectar previamente la batería y el adaptador de corriente para evitar cortocircuitos",\n    "Se requiere confirmación técnica mediante mediciones y lectura de registros para emitir un diagnóstico definitivo"\n  ]\n}	GENERADO	\N	2026-10-18 14:28:01.591992-05	2026-10-18 14:28:01.591992-05	{"warnings": ["No se especifica el código de error BSOD exacto ni el tipo de unidad instalada (HDD o SSD)", "Intentar reparar sectores dañados con herramientas de escritura agresiva puede derivar en pérdida irreversible de datos", "La manipulación interna de la laptop requiere desconectar previamente la batería y el adaptador de corriente para evitar cortocircuitos", "Se requiere confirmación técnica mediante mediciones y lectura de registros para emitir un diagnóstico definitivo"], "classification": "Falla lógica o física de almacenamiento / Inestabilidad de sistema operativo (BSOD)", "possibleCauses": ["Degradación física o presencia de sectores defectuosos en la unidad de almacenamiento (HDD/SSD)", "Corrupción del sistema de archivos o partición de arranque del sistema operativo", "Falso contacto o degradación en el conector SATA/interfaz de la unidad", "Inestabilidad o fallas en la memoria RAM que generen errores de paginación o lectura", "Controladores de almacenamiento incompatibles o dañados tras actualización"], "recommendations": ["Priorizar el respaldo inmediato de información crítica antes de someter la unidad a pruebas de estrés o escritura intensiva", "Evitar reintentos de arranque repetidos que puedan acelerar el daño en un disco mecánico con sectores dañados", "Utilizar un entorno de arranque externo (PE/Live USB) para verificar si la unidad es detectable y legible", "Evaluar el reemplazo por una unidad de estado sólido (SSD) en caso de confirmarse daño en el almacenamiento"], "recommendedTests": ["Ejecutar diagnóstico de salud SMART mediante un entorno Live USB sin iniciar el sistema operativo", "Realizar prueba de diagnóstico de hardware Lenovo (Lenovo Diagnostics) mediante la tecla de función al arranque", "Verificar la integridad del sistema de archivos mediante chkdsk en modo solo lectura desde la consola de recuperación", "Ejecutar test de diagnóstico de memoria RAM (MemTest86 o diagnóstico integrado) para descartar fallas de memoria", "Inspección física y reconexión segura de la unidad de almacenamiento para descartar falso contacto"], "suggestedPriority": "ALTA"}
4abad3be-3a48-4aac-899a-a5892f3164fb	e05a6517-c7d2-40a4-bfdc-8d27b085e5eb	ed8565ad-31a6-4bf7-bfaa-518602317906	gemini	gemini-3.8-flash	{"brand": "lenovo", "model": "ThinkPad E14", "observations": "Se reporta equipo sin energia y sin señales de encendido", "equipmentType": "Laptop", "reportedProblem": "Equipo no enciende", "additionalSymptoms": "", "initialObservations": "Se reporta equipo sin energia y sin señales de encendido", "technicalCharacteristics": "Semi nueva"}	\N	ERROR	Gemini no respondió con un prediagnóstico válido.	2026-11-06 21:54:03.911462-05	2026-11-06 21:54:03.911462-05	\N
fc5b0daa-ac16-411b-9b85-c8fe112f037f	e05a6517-c7d2-40a4-bfdc-8d27b085e5eb	ed8565ad-31a6-4bf7-bfaa-518602317906	gemini	gemini-3.8-flash	{"brand": "lenovo", "model": "ThinkPad E14", "observations": "Se reporta equipo sin energia y sin señales de encendido", "equipmentType": "Laptop", "reportedProblem": "Equipo no enciende", "additionalSymptoms": "", "initialObservations": "Se reporta equipo sin energia y sin señales de encendido", "technicalCharacteristics": "Semi nueva"}	{\n  "classification": "Falla de encendido / Ausencia total de alimentación (No Power)",\n  "suggestedPriority": "ALTA",\n  "possibleCauses": [\n    "Falla o daño en el cargador/adaptador de corriente USB-C",\n    "Batería principal completamente descargada o en estado de bloqueo/protección",\n    "Bloqueo lógico del controlador embebido (Embedded Controller / EC)",\n    "Daño físico o desprendimiento en el puerto de carga USB-C",\n    "Cortocircuito en la etapa de entrada de alimentación o línea principal (VBUS / VIN)",\n    "Falla en los MOSFETs de conmutación de entrada o en el circuito de gestión de energía (PMIC/Charger IC)"\n  ],\n  "recommendedTests": [\n    "Probar con un adaptador de corriente USB-C original y funcional de potencia adecuada (mínimo 65W)",\n    "Realizar un restablecimiento estático mediante el orificio de reinicio de emergencia (pinhole reset) en la base del chasis",\n    "Inspeccionar visualmente el puerto USB-C en busca de suciedad, pines doblados o daño físico",\n    "Observar si el LED de estado junto al conector de carga emite algún parpadeo o iluminación tenue",\n    "Desconectar la batería interna y comprobar si enciende solo con el adaptador conectado",\n    "Medir con multímetro la tensión de entrada USB-C (negociación de Power Delivery a 5V/20V)"\n  ],\n  "recommendations": [\n    "Verificar el estado de la garantía oficial de Lenovo antes de abrir el chasis",\n    "Comenzar el descarte por el botón de reinicio de emergencia antes de cualquier intervención física",\n    "Utilizar protección contra descargas electrostáticas (ESD) si se realiza apertura del chasis",\n    "Evitar el uso de cargadores universales no certificados para ThinkPad"\n  ],\n  "warnings": [\n    "No se dispone de mediciones eléctricas previas de voltaje o consumo de corriente",\n    "La manipulación interna del chasis puede anular la garantía de fábrica si aún está vigente",\n    "Las pruebas en placa base con multímetro requieren conocimientos técnicos y precauciones para no provocar cortocircuitos accidentales"\n  ]\n}	GENERADO	\N	2026-11-06 21:54:38.509376-05	2026-11-06 21:54:38.509376-05	{"warnings": ["No se dispone de mediciones eléctricas previas de voltaje o consumo de corriente", "La manipulación interna del chasis puede anular la garantía de fábrica si aún está vigente", "Las pruebas en placa base con multímetro requieren conocimientos técnicos y precauciones para no provocar cortocircuitos accidentales"], "classification": "Falla de encendido / Ausencia total de alimentación (No Power)", "possibleCauses": ["Falla o daño en el cargador/adaptador de corriente USB-C", "Batería principal completamente descargada o en estado de bloqueo/protección", "Bloqueo lógico del controlador embebido (Embedded Controller / EC)", "Daño físico o desprendimiento en el puerto de carga USB-C", "Cortocircuito en la etapa de entrada de alimentación o línea principal (VBUS / VIN)", "Falla en los MOSFETs de conmutación de entrada o en el circuito de gestión de energía (PMIC/Charger IC)"], "recommendations": ["Verificar el estado de la garantía oficial de Lenovo antes de abrir el chasis", "Comenzar el descarte por el botón de reinicio de emergencia antes de cualquier intervención física", "Utilizar protección contra descargas electrostáticas (ESD) si se realiza apertura del chasis", "Evitar el uso de cargadores universales no certificados para ThinkPad"], "recommendedTests": ["Probar con un adaptador de corriente USB-C original y funcional de potencia adecuada (mínimo 65W)", "Realizar un restablecimiento estático mediante el orificio de reinicio de emergencia (pinhole reset) en la base del chasis", "Inspeccionar visualmente el puerto USB-C en busca de suciedad, pines doblados o daño físico", "Observar si el LED de estado junto al conector de carga emite algún parpadeo o iluminación tenue", "Desconectar la batería interna y comprobar si enciende solo con el adaptador conectado", "Medir con multímetro la tensión de entrada USB-C (negociación de Power Delivery a 5V/20V)"], "suggestedPriority": "ALTA"}
\.


--
-- TOC entry 5312 (class 0 OID 17343)
-- Dependencies: 234
-- Data for Name: ai_validations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ai_validations (id, prediagnosis_id, technician_id, decision, final_diagnosis, observations, validated_at, modified_data) FROM stdin;
\.


--
-- TOC entry 5314 (class 0 OID 17399)
-- Dependencies: 236
-- Data for Name: backup_runs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.backup_runs (id, requested_by, status, file_path, checksum_sha256, started_at, finished_at, error_message) FROM stdin;
\.


--
-- TOC entry 5302 (class 0 OID 17043)
-- Dependencies: 224
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.clients (id, document_type, document_number, first_name, last_name, phone, email, address, observations, created_at, updated_at) FROM stdin;
93253264-d08a-4a36-96c6-94034b8a9dce	DNI	76083706	ERICK MANUEL	RUIZ GUERRA	+5194120665	erickmruiz96@gmail.com	jiron 2 de mayo	prioridad	2026-10-03 18:32:15.305467-05	2026-10-03 18:44:32.026169-05
e96aea1a-4117-4cc7-a881-6ab2a3364824	DNI	75754808	Ruth Anai	Garcia Siancas	946806155	u22302585@utp.edu.pe	sullana		2026-10-09 19:20:59.746823-05	2026-10-09 19:20:59.746823-05
93fecc7d-8d2b-4764-9f02-cb0a07c2e986	DNI	72032456	Fiorela	Garcia Siancas	985678941	fiorisiancas@gmail.com	piura		2026-10-18 13:44:05.291543-05	2026-10-18 13:44:05.291543-05
4f971d71-646d-4ae7-802e-c9f5b20ae6db	DNI	87654321	Ana María	Vásquez Salazar	987654321	Anixmari.salazar@gmail.com	Los cabos verdes SN		2026-10-31 21:21:08.821607-05	2026-10-31 21:21:08.821607-05
0795be60-6fc9-4eb9-9623-cda31d0e328d	DNI	72586942	Melin	bueno arrascue	957633892	mjbaxk24@gmail.com	Canaan s/n		2026-11-06 22:06:57.213344-05	2026-11-06 22:06:57.213344-05
\.


--
-- TOC entry 5303 (class 0 OID 17076)
-- Dependencies: 225
-- Data for Name: equipment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.equipment (id, client_id, type, brand, model, serial_number, characteristics, accessories, observations, created_at, updated_at) FROM stdin;
18913268-cece-4753-aa0d-d0e228958395	93253264-d08a-4a36-96c6-94034b8a9dce	Impresora	EPSON	L365	XR2546SDS		cable de poder y de datos	la impresion sale a rayas ademas de estar con derrame de tinta en los costados	2026-10-03 18:33:38.068254-05	2026-10-03 18:33:38.068254-05
a2a73b0b-e9ec-42d8-b27b-408ad4570df8	93fecc7d-8d2b-4764-9f02-cb0a07c2e986	Laptop	lenovo	g310	XR25264545		cargador y mouse	color palteado con un skim rojo	2026-10-18 13:45:15.203139-05	2026-10-18 13:45:15.203139-05
03022a24-38a0-42b2-9409-489d8ca65e7e	4f971d71-646d-4ae7-802e-c9f5b20ae6db	Laptop	lenovo	ThinkPad E14	QA-2026-001	Semi nueva	Cargador y caja		2026-10-31 21:46:27.82746-05	2026-10-31 21:46:27.82746-05
4372c874-dd4f-42ec-82f5-47c6d43400d8	0795be60-6fc9-4eb9-9623-cda31d0e328d	Impresora	EPSON	l3250	xv25sd52sd4	negra con raspones	cable de poder y de datos		2026-11-06 22:07:47.05464-05	2026-11-06 22:07:47.05464-05
686f9b48-1025-4319-ad41-f04f79a1c609	e96aea1a-4117-4cc7-a881-6ab2a3364824	Monitor	TEROS	T320	CXS52SR56S	negra con raspones	SIN ACCESORIOS		2026-11-06 22:34:28.530596-05	2026-11-06 22:34:28.530596-05
\.


--
-- TOC entry 5297 (class 0 OID 16965)
-- Dependencies: 219
-- Data for Name: flyway_schema_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.flyway_schema_history (installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) FROM stdin;
1	1	complete schema	SQL	V1__complete_schema.sql	-1719685787	postgres	2026-10-03 14:15:17.936418	155	t
2	2	catalogs	SQL	V2__catalogs.sql	-1853366414	postgres	2026-10-03 14:15:18.124425	10	t
3	3	validate client contact details	SQL	V3__validate_client_contact_details.sql	1251041768	postgres	2026-10-09 00:28:01.589933	76	t
4	4	service order intake date and transitions	SQL	V4__service_order_intake_date_and_transitions.sql	1240263402	postgres	2026-10-18 11:15:10.826987	111	t
5	5	technical attentions and ai validation	SQL	V5__technical_attentions_and_ai_validation.sql	313629292	postgres	2026-10-18 11:15:10.962784	35	t
6	6	sprint six audit outcomes	SQL	V6__sprint_six_audit_outcomes.sql	-928675762	postgres	2026-10-18 13:24:18.457969	101	t
\.


--
-- TOC entry 5315 (class 0 OID 17421)
-- Dependencies: 237
-- Data for Name: monitoring_checks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.monitoring_checks (id, component, status, response_time_ms, message, checked_at) FROM stdin;
d3188d87-6b5a-4208-8ecb-cbe3a89beb4c	backend	OK	0	Aplicación disponible	2026-10-18 13:25:41.440699-05
ac056c27-44cc-4894-9f4a-bc660b508b08	postgresql	OK	0	Conexión verificada	2026-10-18 13:25:41.440699-05
bc4836fc-040c-4119-8fa9-97ba5f69a283	gemini	ALERTA	0	No configurado.	2026-10-18 13:25:41.440699-05
624f259e-299a-430c-b0dd-04d9f540bcc4	backend	OK	0	Aplicación disponible	2026-10-18 13:30:18.554725-05
720df69e-6606-4a36-af23-930491de7d1e	postgresql	OK	0	Conexión verificada	2026-10-18 13:30:18.554725-05
a38cedd0-80f3-4177-9ec0-eb39d2214467	gemini	ALERTA	0	No configurado.	2026-10-18 13:30:18.554725-05
624c9a80-1972-4a8e-8584-0698a63321e6	backend	OK	0	Aplicación disponible	2026-10-18 13:39:28.869772-05
4b0f896a-2a46-4fe6-8830-d4d09b526eeb	postgresql	OK	0	Conexión verificada	2026-10-18 13:39:28.869772-05
bbdf0355-e37f-4e5c-8c7d-2b98a4232e30	backend	OK	0	Aplicación disponible	2026-10-18 14:00:37.731944-05
20518589-c35c-4c93-bcbc-e93b1a390fc5	postgresql	OK	0	Conexión verificada	2026-10-18 14:00:37.731944-05
c2152ccd-4d73-4168-a589-4f6732fa9e30	gemini	OK	\N	Solicitud Gemini completada	2026-10-18 14:28:01.596566-05
f9986889-02a7-48ce-8cbd-74b109a8a88c	backend	OK	0	Aplicación disponible	2026-10-18 14:29:48.756099-05
45b18bdf-844f-4594-9baf-c1c35e3f363a	postgresql	OK	0	Conexión verificada	2026-10-18 14:29:48.756099-05
9a0c7b2f-59e4-44f3-b9a9-57e1b77f6385	backend	OK	0	Aplicación disponible	2026-10-24 19:24:37.836353-05
e7c21f57-1688-4cdb-9fbb-6f217302f4ab	postgresql	OK	0	Conexión verificada	2026-10-24 19:24:37.836353-05
b8f66f3f-7688-491b-9078-f6bb62571ff3	gemini	ERROR	\N	Solicitud Gemini fallida	2026-11-06 21:54:03.905105-05
5ff17798-178a-4990-bacf-18f984775dee	gemini	OK	\N	Solicitud Gemini completada	2026-11-06 21:54:38.511389-05
\.


--
-- TOC entry 5309 (class 0 OID 17235)
-- Dependencies: 231
-- Data for Name: order_status_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.order_status_history (id, order_id, from_status, to_status, changed_by, reason, changed_at) FROM stdin;
bb99a932-0534-4c33-8f4b-36849457a5c6	4eac7b12-84dc-4176-bc51-2e1807855335	\N	PENDIENTE	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	Registro de orden	2026-10-18 13:46:29.937956-05
7d63046d-3405-49f0-98ab-4897dd82fe76	4eac7b12-84dc-4176-bc51-2e1807855335	PENDIENTE	EN_ATENCION	3b5b21e1-2d91-4a99-8eb6-37f67b06522b		2026-10-18 17:05:25.087783-05
52de6261-66bd-4c66-8d6b-002bd64a84c5	4eac7b12-84dc-4176-bc51-2e1807855335	EN_ATENCION	FINALIZADA	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	Atención técnica finalizada	2026-10-18 17:47:12.522959-05
9b9e9d9c-c9a6-4843-b7ab-e76d9dc91914	e05a6517-c7d2-40a4-bfdc-8d27b085e5eb	\N	PENDIENTE	ed8565ad-31a6-4bf7-bfaa-518602317906	Registro de orden	2026-11-02 23:43:36.774227-05
e8675138-8709-432f-a802-80c5478694fa	7b4a854d-825e-46e4-b401-9d6fad370dc3	\N	PENDIENTE	ed8565ad-31a6-4bf7-bfaa-518602317906	Registro de orden	2026-11-06 22:08:42.756415-05
bec4e671-d20a-489e-98ba-a67557777c45	e90e9fde-5f78-464d-9ae3-e8236935baa1	\N	PENDIENTE	ed8565ad-31a6-4bf7-bfaa-518602317906	Registro de orden	2026-11-06 22:36:31.215789-05
8bb2405a-e341-4b85-a3bb-70e55c402770	7b4a854d-825e-46e4-b401-9d6fad370dc3	PENDIENTE	EN_ATENCION	3b5b21e1-2d91-4a99-8eb6-37f67b06522b		2026-11-06 23:00:23.292237-05
f41cabe6-1f3b-4799-9a0a-ac939663e512	7b4a854d-825e-46e4-b401-9d6fad370dc3	EN_ATENCION	FINALIZADA	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	Atención técnica finalizada	2026-11-06 23:05:15.065028-05
\.


--
-- TOC entry 5305 (class 0 OID 17124)
-- Dependencies: 227
-- Data for Name: order_status_transitions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.order_status_transitions (from_status, to_status) FROM stdin;
PENDIENTE	ASIGNADA
PENDIENTE	CANCELADA
ASIGNADA	EN_ATENCION
ASIGNADA	CANCELADA
EN_ATENCION	FINALIZADA
EN_ATENCION	CANCELADA
FINALIZADA	EN_ATENCION
FINALIZADA	CERRADA
PENDIENTE	EN_ATENCION
\.


--
-- TOC entry 5304 (class 0 OID 17113)
-- Dependencies: 226
-- Data for Name: order_statuses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.order_statuses (code, name, terminal) FROM stdin;
PENDIENTE	Pendiente	f
ASIGNADA	Asignada	f
EN_ATENCION	En atención	f
FINALIZADA	Finalizada	f
CERRADA	Cerrada	t
CANCELADA	Cancelada	t
\.


--
-- TOC entry 5299 (class 0 OID 16991)
-- Dependencies: 221
-- Data for Name: permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.permissions (code, description) FROM stdin;
dashboard	Ver dashboard
clients	Gestionar clientes
equipment	Gestionar equipos
orders	Gestionar órdenes
assign-technicians	Asignar técnicos
assigned-orders	Consultar órdenes asignadas
attend-orders	Atender órdenes
ai-prediagnosis	Usar prediagnóstico IA
service-tracking	Consultar seguimiento
service-indicators	Consultar indicadores
users	Gestionar usuarios
settings	Configuración
\.


--
-- TOC entry 5300 (class 0 OID 16998)
-- Dependencies: 222
-- Data for Name: role_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.role_permissions (role_code, permission_code) FROM stdin;
ADMINISTRADOR	dashboard
ADMINISTRADOR	clients
ADMINISTRADOR	equipment
ADMINISTRADOR	orders
ADMINISTRADOR	assign-technicians
ADMINISTRADOR	assigned-orders
ADMINISTRADOR	attend-orders
ADMINISTRADOR	ai-prediagnosis
ADMINISTRADOR	service-tracking
ADMINISTRADOR	service-indicators
ADMINISTRADOR	users
ADMINISTRADOR	settings
PERSONAL DE ATENCIÓN	dashboard
PERSONAL DE ATENCIÓN	clients
PERSONAL DE ATENCIÓN	equipment
PERSONAL DE ATENCIÓN	orders
PERSONAL DE ATENCIÓN	service-tracking
TÉCNICO	dashboard
TÉCNICO	assigned-orders
TÉCNICO	attend-orders
TÉCNICO	ai-prediagnosis
TÉCNICO	service-tracking
\.


--
-- TOC entry 5298 (class 0 OID 16982)
-- Dependencies: 220
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.roles (code, name) FROM stdin;
ADMINISTRADOR	Administrador
PERSONAL DE ATENCIÓN	Personal de Atención
TÉCNICO	Técnico
\.


--
-- TOC entry 5307 (class 0 OID 17143)
-- Dependencies: 229
-- Data for Name: service_orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.service_orders (id, number, equipment_id, client_id, received_by, reported_problem, intake_condition, intake_accessories, status_code, priority, estimated_delivery, closed_at, closure_summary, created_at, updated_at, received_at, finalized_at, finalized_by) FROM stdin;
4eac7b12-84dc-4176-bc51-2e1807855335	1	a2a73b0b-e9ec-42d8-b27b-408ad4570df8	93fecc7d-8d2b-4764-9f02-cb0a07c2e986	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	Error con el sistema, pantallazo azul con codigo de disco dañando	se registra la laptop con pantalla azul		FINALIZADA	NORMAL	\N	\N	\N	2026-10-18 13:46:29.937956-05	2026-10-18 17:47:12.522959-05	2026-10-18	2026-10-18 17:47:12.522959-05	3b5b21e1-2d91-4a99-8eb6-37f67b06522b
e05a6517-c7d2-40a4-bfdc-8d27b085e5eb	2	03022a24-38a0-42b2-9409-489d8ca65e7e	4f971d71-646d-4ae7-802e-c9f5b20ae6db	ed8565ad-31a6-4bf7-bfaa-518602317906	Equipo no enciende	Se reporta equipo sin energia y sin señales de encendido		PENDIENTE	ALTA	\N	\N	\N	2026-11-02 23:43:36.774227-05	2026-11-02 23:43:36.774227-05	2026-11-02	\N	\N
e90e9fde-5f78-464d-9ae3-e8236935baa1	4	686f9b48-1025-4319-ad41-f04f79a1c609	e96aea1a-4117-4cc7-a881-6ab2a3364824	ed8565ad-31a6-4bf7-bfaa-518602317906	reyas y parpadeos			PENDIENTE	ALTA	\N	\N	\N	2026-11-06 22:36:31.215789-05	2026-11-06 22:36:31.215789-05	2026-11-06	\N	\N
7b4a854d-825e-46e4-b401-9d6fad370dc3	3	4372c874-dd4f-42ec-82f5-47c6d43400d8	0795be60-6fc9-4eb9-9623-cda31d0e328d	ed8565ad-31a6-4bf7-bfaa-518602317906	Impresion defectuosa ademas de ahcer ruidos al jalar el papel tambien es escaner no funciona correctamente			FINALIZADA	NORMAL	\N	\N	\N	2026-11-06 22:08:42.756415-05	2026-11-06 23:05:15.065028-05	2026-11-06	2026-11-06 23:05:15.065028-05	3b5b21e1-2d91-4a99-8eb6-37f67b06522b
\.


--
-- TOC entry 5313 (class 0 OID 17375)
-- Dependencies: 235
-- Data for Name: system_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.system_events (id, actor_id, event_type, entity_type, entity_id, details, occurred_at, result, description) FROM stdin;
59c90895-8f86-4585-94c1-a0c7619ee17c	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-03 14:26:38.692252-05	SUCCESS	
2cb14f3e-bfcd-48b2-8f29-92b449cfd866	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	UPDATE	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-03 14:27:10.734237-05	SUCCESS	
da7d9310-5eb4-425a-b106-e5c3d6490d21	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-03 14:53:04.004216-05	SUCCESS	
4c3bed59-afad-47c7-a9b5-56744973ed09	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-03 15:40:54.369778-05	SUCCESS	
ab6db56d-8717-41b4-97cf-6bfb822e7a40	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-03 18:30:24.399993-05	SUCCESS	
f203b264-f403-4e18-ba53-ba2b72ff819f	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	CREATE	clients	93253264-d08a-4a36-96c6-94034b8a9dce	{}	2026-10-03 18:32:15.305467-05	SUCCESS	
a874f72e-f942-4dfc-b4ab-9afb3d18db2e	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	CREATE	equipment	18913268-cece-4753-aa0d-d0e228958395	{}	2026-10-03 18:33:38.068254-05	SUCCESS	
1378f3a0-a3ae-4a64-a962-dc01f27f4f80	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-03 18:43:36.07248-05	SUCCESS	
65c9acd1-f479-48a3-acab-eea756358f8e	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	UPDATE	clients	93253264-d08a-4a36-96c6-94034b8a9dce	{}	2026-10-03 18:44:32.026169-05	SUCCESS	
ec3b3103-80df-4b49-8284-1c2eb3d41760	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	PERMISSIONS_CHANGE	roles	\N	{}	2026-10-03 18:45:41.966668-05	SUCCESS	
bbe05962-9573-40ac-bc6d-ff0c08274f83	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	PERMISSIONS_CHANGE	roles	\N	{}	2026-10-03 18:45:43.040151-05	SUCCESS	
75e7cb3f-4e81-4bf5-81b0-18ddcb077a77	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	CREATE	users	b31dd59d-f191-48a3-9970-7e3803b86707	{}	2026-10-03 18:52:39.099246-05	SUCCESS	
6e3192e8-1dce-47f2-8309-1628f839c7f3	b31dd59d-f191-48a3-9970-7e3803b86707	LOGIN	users	b31dd59d-f191-48a3-9970-7e3803b86707	{}	2026-10-03 18:53:02.397017-05	SUCCESS	
eb0dd559-00c8-4b5d-9fcf-c8a4de5f6c21	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-03 18:53:44.66403-05	SUCCESS	
a8ced50f-4d7c-41a7-ab64-b545e5b15291	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-03 19:20:57.357422-05	SUCCESS	
88a44bb9-2bff-40f5-b8d5-a129e1a6e27f	b31dd59d-f191-48a3-9970-7e3803b86707	LOGIN	users	b31dd59d-f191-48a3-9970-7e3803b86707	{}	2026-10-03 19:26:24.260021-05	SUCCESS	
b57553ba-048c-4870-b273-7f985fbdcc62	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-03 19:30:34.412733-05	SUCCESS	
6026778c-9b82-4dfd-9d79-cfe5340f459f	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-09 00:31:09.476865-05	SUCCESS	
30475e7d-9010-47d9-acc1-fb2e010c1367	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	CREATE	clients	62443e22-29eb-4b53-a709-1c3a6823db8d	{}	2026-10-09 00:55:25.989352-05	SUCCESS	
39c3d286-ec83-4ead-8ab7-af3f55c0caf7	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	DELETE	clients	62443e22-29eb-4b53-a709-1c3a6823db8d	{}	2026-10-09 01:12:28.56099-05	SUCCESS	
56717e1e-8de8-4a13-8507-a215c283a00b	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	ACTIVE_CHANGE	users	b31dd59d-f191-48a3-9970-7e3803b86707	{}	2026-10-09 01:12:50.009412-05	SUCCESS	
ad33fdc6-2687-4112-ad54-48777793baf2	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	ACTIVE_CHANGE	users	b31dd59d-f191-48a3-9970-7e3803b86707	{}	2026-10-09 01:12:55.796356-05	SUCCESS	
bba4cf18-f373-48e8-828d-d9a7048c06ee	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	CREATE	users	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	{}	2026-10-09 01:13:48.289292-05	SUCCESS	
ac3af6dc-a27d-42e1-bd3c-8430dc9e8ce3	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	LOGIN	users	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	{}	2026-10-09 01:14:07.679296-05	SUCCESS	
817ffe52-5f51-4e56-9ca6-f17553b6a1cd	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	LOGIN	users	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	{}	2026-10-09 01:36:49.874973-05	SUCCESS	
c9d8a57a-a1a3-4184-88a7-ab66de1c3a52	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-09 01:39:20.900425-05	SUCCESS	
f0ba6da5-82f2-41a7-b300-f8b70c9784ca	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-09 18:00:49.035053-05	SUCCESS	
a4ce4a2e-7d20-49e1-afa8-152e9b09036c	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-09 19:19:12.588176-05	SUCCESS	
74717f2a-591e-49f7-b38e-e972febe859e	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	CREATE	clients	e96aea1a-4117-4cc7-a881-6ab2a3364824	{}	2026-10-09 19:20:59.746823-05	SUCCESS	
d455d196-c0f8-4561-971d-770e744ec7fa	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	LOGIN	users	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	{}	2026-10-09 19:21:40.684068-05	SUCCESS	
cb67740a-78ff-4c06-b1a7-5fa7215ecd61	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-09 19:22:52.393719-05	SUCCESS	
0bc703ef-699a-436b-abcc-20ae156f5286	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-10 18:44:19.379262-05	SUCCESS	
85aec562-e553-4a53-b4c1-518591e160bc	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	LOGIN	users	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	{}	2026-10-10 18:44:57.751127-05	SUCCESS	
977c67ba-8629-49a3-b284-fc5089795d54	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-18 11:39:53.559033-05	SUCCESS	
a6e57673-6847-4398-a044-aedcfe8b14ba	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-18 13:11:45.634096-05	SUCCESS	
272cf88d-e9c6-409d-826e-248f6e69c1cd	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-18 13:25:00.450267-05	SUCCESS	login
c1675f1e-51e5-41cb-9f11-e4d78f6f1da2	\N	LOGIN_FAILED	users	\N	{}	2026-10-18 13:39:16.913543-05	FAILED	Intento de inicio de sesión fallido
71060b9c-0dc0-4d0e-8971-abf20e938045	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-18 13:39:26.108343-05	SUCCESS	login
d200e0fe-8b3f-4b59-bb1f-ede440a849b2	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	CREATE	clients	93fecc7d-8d2b-4764-9f02-cb0a07c2e986	{}	2026-10-18 13:44:05.291543-05	SUCCESS	create
5d930eba-e30b-466b-b229-1c80e5a8b8ae	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	REQUEST_FAILED	equipment	\N	{}	2026-10-18 13:45:05.944148-05	FAILED	La solicitud POST /api/equipment terminó con HTTP 409.
fa788fbd-a764-4abe-b4bb-83481e3392dc	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	CREATE	equipment	a2a73b0b-e9ec-42d8-b27b-408ad4570df8	{}	2026-10-18 13:45:15.203139-05	SUCCESS	create
1c01dbdd-0970-4ee6-aab1-a9587e9d335a	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	CREATE	service_orders	4eac7b12-84dc-4176-bc51-2e1807855335	{}	2026-10-18 13:46:29.937956-05	SUCCESS	create
f5c66020-cf8e-4b23-a2b8-608192efcd07	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	ASSIGN_TECHNICIAN	service_orders	4eac7b12-84dc-4176-bc51-2e1807855335	{}	2026-10-18 13:46:46.968835-05	SUCCESS	assign technician
e4999642-a41e-455f-ac1f-a517578763a7	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-18 13:59:44.267588-05	SUCCESS	login
dff8e08b-202c-4549-b3a2-f2f2585027c7	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGOUT	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-18 14:00:40.923975-05	SUCCESS	Cierre de sesión
9cd9ddcd-8671-4c58-bf38-bfc71d3898ba	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	LOGIN	users	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	{}	2026-10-18 14:00:49.391166-05	SUCCESS	login
007740da-183b-4548-bc35-8663ab6a0179	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	LOGOUT	users	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	{}	2026-10-18 14:02:06.46333-05	SUCCESS	Cierre de sesión
47fc2885-0b41-4952-a76c-34e206811490	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-18 14:02:14.896391-05	SUCCESS	login
0afe152e-76db-460c-9229-e1dfc3d4523a	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGOUT	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-18 14:02:33.188605-05	SUCCESS	Cierre de sesión
3e856309-a246-4cd6-b65a-5e82f1636e9d	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-18 14:02:57.431674-05	SUCCESS	login
8cfba25e-6478-44bf-9f0f-ff1b9e64acc5	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGOUT	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-18 14:03:17.290943-05	SUCCESS	Cierre de sesión
d7cf7fbd-27c0-4642-b9ef-2c44707bf09f	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-18 14:27:46.285269-05	SUCCESS	login
a6cfe581-471a-46d2-bd77-246746c090b4	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	GENERATE_PREDIAGNOSIS	ai_prediagnoses	05c9d944-2f16-41e0-babf-37a68fbf67ea	{}	2026-10-18 14:28:01.599155-05	SUCCESS	Prediagnóstico generado
3de5b862-202e-40f6-8dfc-d188ed8b8f6b	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-18 17:04:08.213939-05	SUCCESS	login
ed4659e3-ae87-466d-8307-1015202c42f0	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGOUT	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-18 17:05:03.675215-05	SUCCESS	Cierre de sesión
a10b8e10-a2ed-4f7a-8a3f-ef9329c13301	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	LOGIN	users	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	{}	2026-10-18 17:05:12.682236-05	SUCCESS	login
3cce0c27-9585-4859-9515-c4472bd2bda2	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	CHANGE_STATUS	service_orders	4eac7b12-84dc-4176-bc51-2e1807855335	{}	2026-10-18 17:05:25.087783-05	SUCCESS	change status
2a49df33-2491-4d8a-950c-3f247e806839	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	LOGIN	users	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	{}	2026-10-18 17:44:31.149543-05	SUCCESS	login
475609e7-be67-4709-adb2-0a266c85372b	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	SAVE_TECHNICAL_ATTENTION	technical_attentions	0665c9c3-6098-4aa1-a787-4d313c938b32	{}	2026-10-18 17:47:12.502693-05	SUCCESS	Registro o actualización de atención técnica
aca1c62b-107f-43b2-9f70-2b1b9bbdfd96	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	FINALIZE_SERVICE_ORDER	service_orders	4eac7b12-84dc-4176-bc51-2e1807855335	{}	2026-10-18 17:47:12.522959-05	SUCCESS	finalize service order
87ca1324-fb9d-4306-812b-7c5ebbb06a75	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	LOGOUT	users	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	{}	2026-10-18 17:48:11.105003-05	SUCCESS	Cierre de sesión
6d3534d3-c4be-4024-b7a0-a848c0333fbb	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-24 19:03:05.900743-05	SUCCESS	login
3175bb55-4aef-4e83-bceb-e8114f5c3460	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGOUT	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-24 19:34:28.686156-05	SUCCESS	Cierre de sesión
dac1823a-28d2-45c0-bd9d-77a5344f1bae	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-24 19:35:35.359517-05	SUCCESS	login
cb440428-38aa-4667-9802-61334bcdc9da	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGOUT	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-24 19:37:31.299739-05	SUCCESS	Cierre de sesión
19548909-a418-4a17-90f0-5027bac1d3b7	\N	LOGIN_FAILED	users	\N	{}	2026-10-24 19:38:55.147499-05	FAILED	Intento de inicio de sesión fallido
d1ae7d3c-b868-4331-ae37-e4f63a0bca2c	\N	LOGIN_FAILED	users	\N	{}	2026-10-24 19:39:00.112098-05	FAILED	Intento de inicio de sesión fallido
7bf9470c-83ec-47dd-8df8-f5b40f36f2bc	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-24 19:39:04.950514-05	SUCCESS	login
e4adfa98-d821-4e4a-8187-a1990c8f943b	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGOUT	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-24 19:43:04.549634-05	SUCCESS	Cierre de sesión
53cb9de7-cb10-4371-9499-5a62c80368a1	\N	LOGIN_FAILED	users	\N	{}	2026-10-24 19:43:14.781274-05	FAILED	Intento de inicio de sesión fallido
2c08f66d-c6c8-4288-a599-a5607f545ca1	b31dd59d-f191-48a3-9970-7e3803b86707	LOGIN	users	b31dd59d-f191-48a3-9970-7e3803b86707	{}	2026-10-24 19:43:21.287485-05	SUCCESS	login
0c19786f-4161-471b-96fc-acf6bc385a4b	b31dd59d-f191-48a3-9970-7e3803b86707	LOGOUT	users	b31dd59d-f191-48a3-9970-7e3803b86707	{}	2026-10-24 19:43:29.835361-05	SUCCESS	Cierre de sesión
d0a7d045-3a8f-4e61-9a05-5f0cd0878c80	\N	LOGIN_FAILED	users	\N	{}	2026-10-24 19:55:31.433233-05	FAILED	Intento de inicio de sesión fallido
c9f1af33-b33c-406a-af87-76eaef002909	\N	LOGIN_FAILED	users	\N	{}	2026-10-31 20:21:24.563777-05	FAILED	Intento de inicio de sesión fallido
af82b420-0349-4f6f-8637-a4a96046c190	\N	LOGIN_FAILED	users	\N	{}	2026-10-31 20:46:39.780493-05	FAILED	Intento de inicio de sesión fallido
cf5bd5fa-a498-4e47-b1e6-458c60dd2be7	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-31 20:46:47.719187-05	SUCCESS	login
6c8ec5d4-594f-4b5e-ae8e-be6a7983d91f	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	CREATE	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-10-31 20:50:18.297851-05	SUCCESS	create
1816c4c4-a018-43c1-b90a-3ada37e082e5	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	CREATE	users	a0c876e3-bec6-42b5-b41d-61820615ebf5	{}	2026-10-31 20:50:56.043893-05	SUCCESS	create
7ab27034-cfd9-46d9-b198-8c3f372884de	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGOUT	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-10-31 20:51:01.856792-05	SUCCESS	Cierre de sesión
630d1c56-e6c4-4560-8c90-6883956c9e84	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGIN	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-10-31 20:52:20.552388-05	SUCCESS	login
fad9b1ca-cb65-4e07-9843-a8fb0c5f79a5	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGOUT	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-10-31 20:52:57.042591-05	SUCCESS	Cierre de sesión
0f1954d6-a5d6-4c22-9d60-3e9c09a5e830	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGIN	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-10-31 20:53:12.335326-05	SUCCESS	login
8b2c9e74-23fc-4413-bb68-1e96001e6b7f	ed8565ad-31a6-4bf7-bfaa-518602317906	UPDATE	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-10-31 20:53:52.546359-05	SUCCESS	update
8e9e0282-7da9-4c55-ba1c-2af461288a03	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGOUT	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-10-31 20:53:55.61255-05	SUCCESS	Cierre de sesión
c5311013-9b93-48a7-8cbc-c4300be1275a	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGIN	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-10-31 20:54:07.145856-05	SUCCESS	login
82215a83-dda8-46b4-996d-95e7ecb66e22	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGOUT	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-10-31 20:54:09.141227-05	SUCCESS	Cierre de sesión
12be432b-065c-462c-bb94-9441da6e9bed	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGIN	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-10-31 20:55:18.433704-05	SUCCESS	login
877767c9-259c-4557-a685-49670c173960	ed8565ad-31a6-4bf7-bfaa-518602317906	CREATE	clients	4f971d71-646d-4ae7-802e-c9f5b20ae6db	{}	2026-10-31 21:21:08.821607-05	SUCCESS	create
b8d31811-32aa-445b-b20c-b7cbde29046e	ed8565ad-31a6-4bf7-bfaa-518602317906	CREATE	equipment	03022a24-38a0-42b2-9409-489d8ca65e7e	{}	2026-10-31 21:46:27.82746-05	SUCCESS	create
20ead1c6-5c31-4185-8b51-99b75168b2a0	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGIN	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-11-02 23:18:38.750324-05	SUCCESS	login
3d39c09a-d843-4b30-8102-759f5c165893	ed8565ad-31a6-4bf7-bfaa-518602317906	CREATE	service_orders	e05a6517-c7d2-40a4-bfdc-8d27b085e5eb	{}	2026-11-02 23:43:36.774227-05	SUCCESS	create
2a3216fb-2fb5-4e25-989f-c903f0092efb	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGOUT	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-11-02 23:52:07.596103-05	SUCCESS	Cierre de sesión
dbc2ea79-744d-4db6-a6f4-8a19cb251749	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:28:39.304173-05	FAILED	Intento de inicio de sesión fallido
6b89b7ff-e0a6-4dbd-973a-d1c452a4a566	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:21.556602-05	FAILED	Intento de inicio de sesión fallido
6df0ce2d-767b-4389-a355-27018257ee51	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:21.570869-05	FAILED	Intento de inicio de sesión fallido
4262a0ec-53c6-4beb-b11d-e4d109e5c4f2	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:21.58384-05	FAILED	Intento de inicio de sesión fallido
93798caa-6cf1-4c02-a72d-bacb6f7fe645	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:21.591663-05	FAILED	Intento de inicio de sesión fallido
23b91697-2b3f-42ed-983a-909a9b8f457b	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:21.603682-05	FAILED	Intento de inicio de sesión fallido
9f096331-d61b-41cd-ab5b-2fd662cb1223	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:21.632862-05	FAILED	Intento de inicio de sesión fallido
5b23073c-a854-4132-b75a-a6de520d0a5d	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:21.660109-05	FAILED	Intento de inicio de sesión fallido
671627dd-9449-44a9-8f47-5cd83a68770f	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:21.684844-05	FAILED	Intento de inicio de sesión fallido
b8183d03-c727-4549-9d44-61a7c1629003	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:21.691144-05	FAILED	Intento de inicio de sesión fallido
9488d6e8-2090-48c2-9e33-272392b06f91	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.042828-05	FAILED	Intento de inicio de sesión fallido
add0e060-69e1-4739-9958-4b9c03c57293	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.049049-05	FAILED	Intento de inicio de sesión fallido
386fb28e-6c16-4069-a97c-5a4b574d964c	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.066397-05	FAILED	Intento de inicio de sesión fallido
94b45ca7-ac3d-4652-bfaf-fbded3b5b601	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.080696-05	FAILED	Intento de inicio de sesión fallido
3205a1c8-fba7-4cf5-a0c2-60889887ed4a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.079513-05	FAILED	Intento de inicio de sesión fallido
e165f3ec-1242-4335-b952-9f4233b93dbf	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.086491-05	FAILED	Intento de inicio de sesión fallido
13d12fa2-a08b-423b-8eb9-c87c2c4ff1bf	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.08878-05	FAILED	Intento de inicio de sesión fallido
b96e9d62-adcb-42ee-bbde-f1f270f5a5f1	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.095225-05	FAILED	Intento de inicio de sesión fallido
4041a047-c4b6-4359-8771-5e6b7a003059	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.102359-05	FAILED	Intento de inicio de sesión fallido
69f85b04-c648-4f5c-bb90-9713d4e10eb5	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.109453-05	FAILED	Intento de inicio de sesión fallido
7b017c29-6fbb-4768-91e0-2097a3424935	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.113299-05	FAILED	Intento de inicio de sesión fallido
c1f8a8cf-128b-4ad9-9310-02ee88f9995c	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.669916-05	FAILED	Intento de inicio de sesión fallido
9e60642b-cbcc-4802-814a-14c408d3f81a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.68001-05	FAILED	Intento de inicio de sesión fallido
34a77041-467f-43ce-b86e-54e5d5b8f542	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.685565-05	FAILED	Intento de inicio de sesión fallido
ff901ddb-a406-4a69-8c9b-431efe80d4ad	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.70937-05	FAILED	Intento de inicio de sesión fallido
69e2177d-87b4-4f1c-8bdc-4af1872bce65	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.751354-05	FAILED	Intento de inicio de sesión fallido
a9e9db20-1a35-454b-a3e5-2f751a78fdb9	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.765692-05	FAILED	Intento de inicio de sesión fallido
0ebf7d8c-6fc4-49c4-afdc-904c97b33db4	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.848708-05	FAILED	Intento de inicio de sesión fallido
1d3a22ef-c90f-47c9-ba91-04a22712ef81	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.907463-05	FAILED	Intento de inicio de sesión fallido
9ced265c-2c8f-408c-bca7-bea824e94bd3	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:22.946062-05	FAILED	Intento de inicio de sesión fallido
ac562208-d1d3-4245-95ca-d15c9baaeecf	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:23.14779-05	FAILED	Intento de inicio de sesión fallido
45e3b769-c2d0-46be-ba84-cc46da048774	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:23.18667-05	FAILED	Intento de inicio de sesión fallido
07352e0a-0dca-4fb4-ab5c-1eff58725f53	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:23.19342-05	FAILED	Intento de inicio de sesión fallido
6b7e7315-4b81-4cef-b78e-210ff3bd92bc	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:23.197238-05	FAILED	Intento de inicio de sesión fallido
a73aa243-4bab-4498-b6db-0a6e35f9d95a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:23.200996-05	FAILED	Intento de inicio de sesión fallido
90a2f3c3-d342-4291-84a5-8774b2c2fc2a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:23.406196-05	FAILED	Intento de inicio de sesión fallido
98230002-2c02-4371-b0a4-f366e35519fb	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:23.406834-05	FAILED	Intento de inicio de sesión fallido
97c75685-911e-4859-9670-ab1ae185af8d	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:23.430479-05	FAILED	Intento de inicio de sesión fallido
93675482-3d32-41cd-9d79-1891e13be085	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.057865-05	FAILED	Intento de inicio de sesión fallido
7be573c4-38d4-41f1-8a98-3a129fa78880	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.00866-05	FAILED	Intento de inicio de sesión fallido
98aebb81-3482-4b6b-8662-421a3f8d69a9	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.712983-05	FAILED	Intento de inicio de sesión fallido
03e52af5-3383-4e7c-a0a8-480d0aeb9bcd	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.035481-05	FAILED	Intento de inicio de sesión fallido
134bdf66-5667-46d7-98d8-1dc778d7b739	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.85221-05	FAILED	Intento de inicio de sesión fallido
170f72f8-edf7-4a51-8544-3faf9ffd62b0	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.38438-05	FAILED	Intento de inicio de sesión fallido
64107c9a-12c4-4e9b-938d-f039fdee653e	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.590564-05	FAILED	Intento de inicio de sesión fallido
c141a615-5a89-4e32-be2d-d91224b3b0f4	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.195548-05	FAILED	Intento de inicio de sesión fallido
1d856969-d33d-472a-b1d2-f3dc55cff689	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.789178-05	FAILED	Intento de inicio de sesión fallido
987c39f4-a1b9-416c-a5e5-61be4a82077a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:29.441404-05	FAILED	Intento de inicio de sesión fallido
85aa1e5b-c55d-4332-a86b-f2d9d3e5ecb4	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:30.128278-05	FAILED	Intento de inicio de sesión fallido
119681c1-04f5-4c62-a14a-4e3af6c622c2	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:30.622047-05	FAILED	Intento de inicio de sesión fallido
2b0198ed-d66b-4fb8-9937-7c843191cf60	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.232227-05	FAILED	Intento de inicio de sesión fallido
b51ebb29-3794-416a-a88f-33dbb9ed47e6	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:32.099546-05	FAILED	Intento de inicio de sesión fallido
ebe00205-ef8f-4406-a649-32e7a8acb391	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:32.558793-05	FAILED	Intento de inicio de sesión fallido
4b2771d8-24b7-4b0e-81a7-434382a987c5	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.137625-05	FAILED	Intento de inicio de sesión fallido
469a2802-c76b-4d52-9cc6-127df6d35a15	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.727872-05	FAILED	Intento de inicio de sesión fallido
fb3cdb7e-67bd-4e35-b2a0-88aa4121784a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.852835-05	FAILED	Intento de inicio de sesión fallido
1b0cb05c-1a35-42e9-822d-b474f2f54b1b	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:23.434841-05	FAILED	Intento de inicio de sesión fallido
b2b8420e-fa1c-4dd1-b008-114dfdd2c4fb	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:23.722845-05	FAILED	Intento de inicio de sesión fallido
2e8f1ce5-6a82-4153-88ca-9b95deaadd2a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.021184-05	FAILED	Intento de inicio de sesión fallido
5205659f-a6e4-40cf-9169-7cff4bcec73f	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.056068-05	FAILED	Intento de inicio de sesión fallido
13875657-a76e-4e2c-9f07-c067a18d0785	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.396702-05	FAILED	Intento de inicio de sesión fallido
97d630e2-e4eb-4610-996a-57474ed14193	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.454076-05	FAILED	Intento de inicio de sesión fallido
fccd8318-bdb5-4502-a96b-5de15938ad92	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.708692-05	FAILED	Intento de inicio de sesión fallido
902debb4-78c5-44ce-a015-aed5178400c4	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.075378-05	FAILED	Intento de inicio de sesión fallido
b4d76684-0d9f-4b49-a890-fef24e24f9e4	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.397669-05	FAILED	Intento de inicio de sesión fallido
04454f4d-0445-431d-9ab8-1e8288ab07ac	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.497576-05	FAILED	Intento de inicio de sesión fallido
e03a25c6-04e0-4dea-a28c-302802d2e0a9	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.580587-05	FAILED	Intento de inicio de sesión fallido
7e740519-5b04-4054-9111-3fe8591646b5	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.799636-05	FAILED	Intento de inicio de sesión fallido
6ebac709-36f2-4b5e-b893-1b4afac5e017	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.830348-05	FAILED	Intento de inicio de sesión fallido
5245c786-8106-4f2e-b733-8305b815fcaa	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.990888-05	FAILED	Intento de inicio de sesión fallido
34058ffc-b61f-44df-a7c3-74045478961a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.105727-05	FAILED	Intento de inicio de sesión fallido
6a3e47d4-d6e4-4362-a420-6f87d8f310ea	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.113962-05	FAILED	Intento de inicio de sesión fallido
2a83ad74-b5f3-44ad-b604-3e63b17b6ee2	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.146067-05	FAILED	Intento de inicio de sesión fallido
4307b4ab-a851-43be-b8b2-93524030f184	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.605357-05	FAILED	Intento de inicio de sesión fallido
ab59d969-fe59-406c-bfc7-c4d8e564a1d0	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.919867-05	FAILED	Intento de inicio de sesión fallido
56afb71f-3c05-4f90-a535-04e25abe9c43	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.943126-05	FAILED	Intento de inicio de sesión fallido
d2d5e64e-7e59-4b1a-89a5-e7dd47c845c3	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.048732-05	FAILED	Intento de inicio de sesión fallido
b9f343b3-ab3e-491c-916c-ff26a4b30894	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.460647-05	FAILED	Intento de inicio de sesión fallido
2ec59253-ec10-4ea9-8042-8d3143dc70c2	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.479496-05	FAILED	Intento de inicio de sesión fallido
65be397a-eab4-4bd6-9dd2-fbc96be58102	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.510366-05	FAILED	Intento de inicio de sesión fallido
7c2088ae-7e41-4d63-a3c1-9ac7572c4ffe	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.579471-05	FAILED	Intento de inicio de sesión fallido
aee79d59-0da9-432d-ac99-cf12300545fd	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.952442-05	FAILED	Intento de inicio de sesión fallido
ab2fcacf-355a-45a2-9f5e-ef1e42ad3b3d	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.986543-05	FAILED	Intento de inicio de sesión fallido
54aaa480-3730-418e-b91b-90366b3f2bcf	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.028414-05	FAILED	Intento de inicio de sesión fallido
422a0ad6-8e75-454e-a203-645f0969bfd8	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.076637-05	FAILED	Intento de inicio de sesión fallido
1319f582-c325-41a4-9283-1a4c01b5ecff	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.520016-05	FAILED	Intento de inicio de sesión fallido
6c683bbb-2475-49f6-b9d9-2baa658b7d40	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.541078-05	FAILED	Intento de inicio de sesión fallido
f2aec5ee-ea81-4ebe-b9d4-3f11558501e4	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.67706-05	FAILED	Intento de inicio de sesión fallido
9f805c23-8884-4e4b-bb61-20a688dd79dd	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.690685-05	FAILED	Intento de inicio de sesión fallido
3252bf32-42d7-48ab-9f94-dbd1842faaab	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.919661-05	FAILED	Intento de inicio de sesión fallido
f0cf5f87-d0b0-465f-923f-488408a8598e	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.970824-05	FAILED	Intento de inicio de sesión fallido
68eda37b-c024-43f5-825a-5f6225f4c2de	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:29.104105-05	FAILED	Intento de inicio de sesión fallido
7a25c8b7-790d-4785-be29-4f67fccda165	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:29.449505-05	FAILED	Intento de inicio de sesión fallido
0544871e-058b-4cfd-a238-6eedb1412d3c	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:29.471753-05	FAILED	Intento de inicio de sesión fallido
753d832d-f432-445d-9668-98c067884ace	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:29.590544-05	FAILED	Intento de inicio de sesión fallido
0a8beb46-0137-4325-8f64-d2ca99dae323	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:29.645458-05	FAILED	Intento de inicio de sesión fallido
1e6c8764-087c-428d-89be-f518362111c7	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:29.694882-05	FAILED	Intento de inicio de sesión fallido
52e3de6f-f777-4460-86de-ebfd6d0bdc01	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:29.852293-05	FAILED	Intento de inicio de sesión fallido
e4fb42a0-f750-458b-b4c8-9b37e4b2c8e9	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:29.979625-05	FAILED	Intento de inicio de sesión fallido
4a1e88b6-5815-4a9f-8a8e-57a4c7095079	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:30.084192-05	FAILED	Intento de inicio de sesión fallido
7b692982-45d2-4026-8d98-5dcf3abf5c79	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:30.53479-05	FAILED	Intento de inicio de sesión fallido
d1ba3191-8c58-4e01-b989-79f01ffb99ec	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:30.620795-05	FAILED	Intento de inicio de sesión fallido
0d10b8a5-999b-493c-b4e6-a2b2fed7f9ea	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:30.914761-05	FAILED	Intento de inicio de sesión fallido
ab13e0dc-a70c-4ef8-9f52-b5f442d022c3	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:30.990971-05	FAILED	Intento de inicio de sesión fallido
608a9a50-718b-413c-9d99-782701dde18e	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.012921-05	FAILED	Intento de inicio de sesión fallido
fa8764e4-6f91-4e8d-b1c2-755d5af0239f	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.049409-05	FAILED	Intento de inicio de sesión fallido
37e6c995-d292-4012-8789-c1cac301e032	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.171209-05	FAILED	Intento de inicio de sesión fallido
82680a87-49ee-4c5a-8236-21c2c0315b25	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.298882-05	FAILED	Intento de inicio de sesión fallido
2341861b-ef9d-4031-aafe-cae7eaecf066	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.355723-05	FAILED	Intento de inicio de sesión fallido
9c187449-955d-459e-b1d1-f10709d68a00	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.502481-05	FAILED	Intento de inicio de sesión fallido
a55d7d25-89cc-4173-a5cc-4cee070fefad	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.541905-05	FAILED	Intento de inicio de sesión fallido
6f28c690-fb6d-41b3-ac66-8d56d09dba4a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.60588-05	FAILED	Intento de inicio de sesión fallido
2e2ea310-a23d-4691-86c0-28104ed0150d	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.770516-05	FAILED	Intento de inicio de sesión fallido
b38a1bd8-139e-4636-9745-bd283008d38b	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:32.206478-05	FAILED	Intento de inicio de sesión fallido
cdf7442c-2c6b-4533-bac0-0a5aafcf1af7	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:32.217619-05	FAILED	Intento de inicio de sesión fallido
318f36ff-0d88-46e2-aa63-c6ebfc56eb3a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:32.411593-05	FAILED	Intento de inicio de sesión fallido
1958b04a-df8d-4cb7-af98-1803fb5b57bf	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:32.423257-05	FAILED	Intento de inicio de sesión fallido
fbcb8482-97de-4e7c-9eb2-6556e8b0faef	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:23.436179-05	FAILED	Intento de inicio de sesión fallido
56d523d5-aa0d-440c-936f-7b7187e0cc40	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.753646-05	FAILED	Intento de inicio de sesión fallido
fd43d373-66ba-487f-9ddc-a4ce20203191	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.465459-05	FAILED	Intento de inicio de sesión fallido
3727f699-a887-450a-85ea-f64c189a685a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.882347-05	FAILED	Intento de inicio de sesión fallido
c720c372-cebd-4054-9453-473aa3ccb824	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:30.813106-05	FAILED	Intento de inicio de sesión fallido
47e4a5bc-32a8-459d-992e-fb4089c3986e	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:32.640674-05	FAILED	Intento de inicio de sesión fallido
22f8b67e-1a4d-453f-b8ad-8f779ebea81b	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:23.47007-05	FAILED	Intento de inicio de sesión fallido
8dbb217f-bafd-4836-b622-fefde35bba69	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:23.940592-05	FAILED	Intento de inicio de sesión fallido
960b607f-9535-4d00-9a0f-b6418a921513	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.009533-05	FAILED	Intento de inicio de sesión fallido
0670a0ea-8418-4281-b7d5-28f9069afa66	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.040022-05	FAILED	Intento de inicio de sesión fallido
51465f63-ee82-47d3-b0d0-77962abcf455	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.044655-05	FAILED	Intento de inicio de sesión fallido
93a5c0b5-7b3c-4240-be1c-3914e54d65b8	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.086858-05	FAILED	Intento de inicio de sesión fallido
fb3755b5-ae65-47d0-a583-ea26ce36a80c	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.432196-05	FAILED	Intento de inicio de sesión fallido
fb7aed64-63ec-495f-b0f3-1f79b60fef5f	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.441211-05	FAILED	Intento de inicio de sesión fallido
4ceec560-d7f5-4d8e-8e40-850ef84f612f	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.599089-05	FAILED	Intento de inicio de sesión fallido
6648b6ad-372e-46da-b39c-016ac4144c89	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.703839-05	FAILED	Intento de inicio de sesión fallido
7e10665a-8ed3-4de4-8653-5c9cbcbd657f	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.706598-05	FAILED	Intento de inicio de sesión fallido
963bff7c-28ff-40da-a4e7-c53a41e41a06	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.718984-05	FAILED	Intento de inicio de sesión fallido
0b089f48-b744-46dc-9916-5c38ed06f165	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:24.724127-05	FAILED	Intento de inicio de sesión fallido
e61071fb-6726-451a-8a33-a6e24efddd73	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.080691-05	FAILED	Intento de inicio de sesión fallido
5719f1ef-a13b-4dcc-9f5b-47597bc385d1	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.090109-05	FAILED	Intento de inicio de sesión fallido
f2a6b2b3-c082-4694-9759-84ff279f885a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.466899-05	FAILED	Intento de inicio de sesión fallido
ed4435da-5c3b-4420-9086-cf85e4b2b153	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.583895-05	FAILED	Intento de inicio de sesión fallido
6c021b59-0034-4b4f-9904-492091d1a615	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.817097-05	FAILED	Intento de inicio de sesión fallido
55dd0b3e-e6f4-4b47-9c69-5cec072b5e7b	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:25.997589-05	FAILED	Intento de inicio de sesión fallido
c3b70ff3-2d94-431f-8510-a518f37defde	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.006077-05	FAILED	Intento de inicio de sesión fallido
dd41b07e-74c9-4d2b-bed7-a80f28e4e19c	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.011115-05	FAILED	Intento de inicio de sesión fallido
7e18c6bb-f5e1-4067-bbe0-9d5ee6dfe6ee	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.111274-05	FAILED	Intento de inicio de sesión fallido
42b8f9eb-300c-4294-87f2-0bd725c40ff5	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.124628-05	FAILED	Intento de inicio de sesión fallido
1940f582-41dd-43d5-8f0e-858d8faf70cc	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.481954-05	FAILED	Intento de inicio de sesión fallido
dc03c745-5ba1-4205-ab35-e8662c2cf7c0	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.655942-05	FAILED	Intento de inicio de sesión fallido
0669d956-3a5b-414f-9fad-0ca553d2ed6d	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.670311-05	FAILED	Intento de inicio de sesión fallido
8337244a-46b5-4fb6-bfe3-fa48db7d23c1	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.898301-05	FAILED	Intento de inicio de sesión fallido
e31dc450-940b-41ff-b610-736406ec494a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:26.931514-05	FAILED	Intento de inicio de sesión fallido
34a51082-9500-43fa-bea1-d806420f19de	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.092211-05	FAILED	Intento de inicio de sesión fallido
7d00fb97-881b-43d7-bc5b-96b62693ed78	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.460857-05	FAILED	Intento de inicio de sesión fallido
cba044bb-43a5-4c3b-b65a-18c7a5d0cbaa	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.567277-05	FAILED	Intento de inicio de sesión fallido
287e2e85-2bb2-4a14-b3e6-5cee7c9e4dc4	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.610918-05	FAILED	Intento de inicio de sesión fallido
a9874aec-c388-4944-84e7-4c85f7191885	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.71079-05	FAILED	Intento de inicio de sesión fallido
a2c18031-5f70-450b-85b7-6e944df58703	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.981514-05	FAILED	Intento de inicio de sesión fallido
95c29865-8c63-44ef-9529-ed2dd17e4560	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:27.98738-05	FAILED	Intento de inicio de sesión fallido
f2767913-3872-43aa-b714-7d110afbf95b	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.02527-05	FAILED	Intento de inicio de sesión fallido
1503a6ed-513a-4489-a7f6-9b096ec67805	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.233949-05	FAILED	Intento de inicio de sesión fallido
1bb8cfda-065e-4529-afc9-abed9a67bcea	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.534068-05	FAILED	Intento de inicio de sesión fallido
a7122d01-96d8-4c96-8113-c4ba47e08036	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.600904-05	FAILED	Intento de inicio de sesión fallido
d1142a51-b4f6-4ccf-9456-2cd85015b1a6	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.826293-05	FAILED	Intento de inicio de sesión fallido
96bd2a08-1487-4890-93d1-b5e5c3e83d40	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:28.972739-05	FAILED	Intento de inicio de sesión fallido
d4dbfd17-9d98-4f6a-916e-526b010c9a31	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:29.006506-05	FAILED	Intento de inicio de sesión fallido
1cd3cceb-85dd-46e3-b137-8ec8daed0e40	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:29.270246-05	FAILED	Intento de inicio de sesión fallido
f07d335f-d095-498b-83f7-860c540ad8c2	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:29.438167-05	FAILED	Intento de inicio de sesión fallido
ab4aa835-fa15-44ea-94ab-59c7fca77206	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:29.830881-05	FAILED	Intento de inicio de sesión fallido
ab40c584-3c8c-4a25-9c09-1ed4ad25574a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:29.936016-05	FAILED	Intento de inicio de sesión fallido
c47b34d9-d42d-48ec-8cb6-7ee0bc97429a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:30.012538-05	FAILED	Intento de inicio de sesión fallido
a27b4a00-80bd-43ce-a6b5-1eec9a46cb72	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:30.038245-05	FAILED	Intento de inicio de sesión fallido
58795d5b-ade2-424f-a4d1-61fdeabced65	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:30.518782-05	FAILED	Intento de inicio de sesión fallido
88d9a6cd-a4d8-4a55-95df-142b29440309	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:30.543997-05	FAILED	Intento de inicio de sesión fallido
bebf23f0-cdb5-4cc0-a850-c15e06b175f2	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:30.600625-05	FAILED	Intento de inicio de sesión fallido
a0f9d09e-dc6c-4ee0-a9b6-322f37c5f727	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:30.714155-05	FAILED	Intento de inicio de sesión fallido
b398e51f-22ea-4da2-8b76-d440805ef4b4	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.085349-05	FAILED	Intento de inicio de sesión fallido
55c92d33-5d32-4137-9f6d-8810efe4b227	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.148749-05	FAILED	Intento de inicio de sesión fallido
72926d3b-6b94-4038-aa36-a9b8140def16	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.193563-05	FAILED	Intento de inicio de sesión fallido
14682972-cbb0-4918-8ccf-a1c2b14f61ff	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.559444-05	FAILED	Intento de inicio de sesión fallido
f95d260f-66b8-4feb-9768-69dd4bfd3d82	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.672577-05	FAILED	Intento de inicio de sesión fallido
632ed730-e374-4d8d-b647-443e98dc48cb	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:31.875204-05	FAILED	Intento de inicio de sesión fallido
6a4db491-6115-486a-bac6-427f6364fda6	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:32.069599-05	FAILED	Intento de inicio de sesión fallido
2147fc15-4571-4269-bcd2-d9acb8facdbf	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:32.149547-05	FAILED	Intento de inicio de sesión fallido
c4f2b7bd-0c73-47ff-b51d-c25d55f501c3	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:32.29655-05	FAILED	Intento de inicio de sesión fallido
c283689c-d9cf-4c31-ad42-4e44692d0d84	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:32.432285-05	FAILED	Intento de inicio de sesión fallido
8f766ea5-a07d-49a0-8a1a-ed7be46159b9	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:32.51811-05	FAILED	Intento de inicio de sesión fallido
ce772d54-1fe4-4bfd-9544-d455fdd4e7e1	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:32.590912-05	FAILED	Intento de inicio de sesión fallido
2f671ccd-d937-4faf-ab91-010ec6e42698	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.016961-05	FAILED	Intento de inicio de sesión fallido
f4f98278-0b46-43b4-ba6c-695ded9e9964	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.251939-05	FAILED	Intento de inicio de sesión fallido
ee9c5085-adfe-4b5c-b320-f7ea8c7773d6	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.349421-05	FAILED	Intento de inicio de sesión fallido
c3e99e3a-256b-4f4f-b4e6-25d7c754842b	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.42196-05	FAILED	Intento de inicio de sesión fallido
85292d21-b53c-4de9-b9d5-80c344fb62e2	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.571774-05	FAILED	Intento de inicio de sesión fallido
52879f4c-1290-487b-8543-884d3c97116f	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.618907-05	FAILED	Intento de inicio de sesión fallido
49f0767d-c536-4464-8703-c9b332c60e46	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.674042-05	FAILED	Intento de inicio de sesión fallido
835acc85-f7b5-4daf-acda-6f0bf3f90610	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.725936-05	FAILED	Intento de inicio de sesión fallido
78c4aba3-4cbf-446c-9a95-56a8af30aa44	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.886626-05	FAILED	Intento de inicio de sesión fallido
cfe32601-b5b2-4aa9-b90a-26f49056417a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:31:02.961932-05	FAILED	Intento de inicio de sesión fallido
eab5751d-48d8-4b3b-a60d-7c9195a976e2	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:32.718045-05	FAILED	Intento de inicio de sesión fallido
df6db5d2-3c4e-459d-b2f5-592fa707bd88	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.012617-05	FAILED	Intento de inicio de sesión fallido
5c2c8298-779e-4aea-b631-b1896f128fe7	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.186057-05	FAILED	Intento de inicio de sesión fallido
6a2e694d-ea26-4ddd-b538-95a4352aedea	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.251585-05	FAILED	Intento de inicio de sesión fallido
ec9947d0-d340-4b9b-9362-585aea285888	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.291084-05	FAILED	Intento de inicio de sesión fallido
27a34fd1-68ca-40ad-95ac-0dca04349d6a	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.329018-05	FAILED	Intento de inicio de sesión fallido
ed32b85a-acfa-4fca-a8de-c2cd62e17d5c	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.421976-05	FAILED	Intento de inicio de sesión fallido
e60790f6-9b7c-43f6-b140-8163c5595fce	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.570807-05	FAILED	Intento de inicio de sesión fallido
d9b0cbe1-3637-4e83-a8bd-0a302d2ea054	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.611457-05	FAILED	Intento de inicio de sesión fallido
72b16a94-6346-4ad6-9882-04c04183db97	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.647913-05	FAILED	Intento de inicio de sesión fallido
00a690f3-075d-4b2e-89ed-1947e32268f3	\N	LOGIN_FAILED	users	\N	{}	2026-11-04 00:30:33.783535-05	FAILED	Intento de inicio de sesión fallido
dd1e9f35-726c-4701-a0cb-f71c9ebe5fee	\N	LOGIN_FAILED	users	\N	{}	2026-11-06 20:25:28.76789-05	FAILED	Intento de inicio de sesión fallido
fa68c8b1-bad0-4ddd-a6a5-d4a27f592b79	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGIN	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-11-06 20:31:56.293111-05	SUCCESS	login
f864a8c1-5c5d-48ae-898d-9185f890b8f2	ed8565ad-31a6-4bf7-bfaa-518602317906	REQUEST_FAILED	equipment	\N	{}	2026-11-06 20:34:30.398077-05	FAILED	La solicitud POST /api/equipment terminó con HTTP 409.
4d14c4d9-4670-4fe7-b4ad-1b8b2e246510	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGIN	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-11-06 21:27:49.209793-05	SUCCESS	login
2db64d2a-5964-4e37-9f5b-f3dc3bebcd38	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGIN	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-11-06 21:43:28.355008-05	SUCCESS	login
0a83bfa7-4c46-4b8e-8677-696ff496fa05	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGIN	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-11-06 21:46:23.399492-05	SUCCESS	login
cd90366b-6de0-409e-8d1b-cbc035bc4286	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGIN	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-11-06 21:51:44.24416-05	SUCCESS	login
738bdcf1-1b2b-4244-8246-14aff2a844df	ed8565ad-31a6-4bf7-bfaa-518602317906	GENERATE_PREDIAGNOSIS	ai_prediagnoses	4abad3be-3a48-4aac-899a-a5892f3164fb	{}	2026-11-06 21:54:03.91498-05	FAILED	Falló la generación del prediagnóstico
e28c2368-e9a1-4e29-ae24-bb4d15f94731	ed8565ad-31a6-4bf7-bfaa-518602317906	REQUEST_FAILED	orders/{id}/prediagnoses	\N	{}	2026-11-06 21:54:03.918348-05	FAILED	La solicitud POST /api/orders/{id}/prediagnoses terminó con HTTP 502.
8cade987-ddf5-4218-a221-5be49479cbdd	ed8565ad-31a6-4bf7-bfaa-518602317906	GENERATE_PREDIAGNOSIS	ai_prediagnoses	fc5b0daa-ac16-411b-9b85-c8fe112f037f	{}	2026-11-06 21:54:38.51189-05	SUCCESS	Prediagnóstico generado
842ea22f-f3d7-426a-89bb-5ad332751e3b	ed8565ad-31a6-4bf7-bfaa-518602317906	CREATE	clients	0795be60-6fc9-4eb9-9623-cda31d0e328d	{}	2026-11-06 22:06:57.213344-05	SUCCESS	create
bbbc2804-ab64-4add-a092-76651df44ae4	ed8565ad-31a6-4bf7-bfaa-518602317906	CREATE	equipment	4372c874-dd4f-42ec-82f5-47c6d43400d8	{}	2026-11-06 22:07:47.05464-05	SUCCESS	create
b1437dec-9a88-450d-b0fc-8c0773a016cc	ed8565ad-31a6-4bf7-bfaa-518602317906	CREATE	service_orders	7b4a854d-825e-46e4-b401-9d6fad370dc3	{}	2026-11-06 22:08:42.756415-05	SUCCESS	create
697d2c5c-19fe-4292-a96c-ffa3a1e3636f	ed8565ad-31a6-4bf7-bfaa-518602317906	ASSIGN_TECHNICIAN	service_orders	7b4a854d-825e-46e4-b401-9d6fad370dc3	{}	2026-11-06 22:09:05.30923-05	SUCCESS	assign technician
f8dbed1e-7ce6-4795-b80b-9246a4f86fb9	ed8565ad-31a6-4bf7-bfaa-518602317906	ASSIGN_TECHNICIAN	service_orders	e05a6517-c7d2-40a4-bfdc-8d27b085e5eb	{}	2026-11-06 22:09:19.308211-05	SUCCESS	assign technician
bcf9b486-d76c-4f6c-9d37-10c2c75101f6	ed8565ad-31a6-4bf7-bfaa-518602317906	ACTIVE_CHANGE	users	b31dd59d-f191-48a3-9970-7e3803b86707	{}	2026-11-06 22:10:06.379404-05	SUCCESS	active change
20bfaf46-228c-4564-928d-312eb5a694f0	ed8565ad-31a6-4bf7-bfaa-518602317906	ACTIVE_CHANGE	users	b31dd59d-f191-48a3-9970-7e3803b86707	{}	2026-11-06 22:10:39.870277-05	SUCCESS	active change
540d09d1-3360-4e00-b081-ca03c9f4455d	ed8565ad-31a6-4bf7-bfaa-518602317906	ASSIGN_TECHNICIAN	service_orders	e05a6517-c7d2-40a4-bfdc-8d27b085e5eb	{}	2026-11-06 22:10:55.42995-05	SUCCESS	assign technician
46f144d0-5195-4270-bb15-d79b236c05a3	ed8565ad-31a6-4bf7-bfaa-518602317906	CREATE	equipment	686f9b48-1025-4319-ad41-f04f79a1c609	{}	2026-11-06 22:34:28.530596-05	SUCCESS	create
517bce8b-c739-4e78-a94f-46205f78bb93	ed8565ad-31a6-4bf7-bfaa-518602317906	REQUEST_FAILED	orders	\N	{}	2026-11-06 22:35:22.006775-05	FAILED	La solicitud POST /api/orders terminó con HTTP 400.
bd325ea3-eb6e-4c00-928f-e1e38b26d040	ed8565ad-31a6-4bf7-bfaa-518602317906	REQUEST_FAILED	orders	\N	{}	2026-11-06 22:35:59.157901-05	FAILED	La solicitud POST /api/orders terminó con HTTP 400.
f8810d11-43a8-47a1-99e9-8bd25a2fc529	ed8565ad-31a6-4bf7-bfaa-518602317906	CREATE	service_orders	e90e9fde-5f78-464d-9ae3-e8236935baa1	{}	2026-11-06 22:36:31.215789-05	SUCCESS	create
e9454271-211d-4a3a-8f12-6acfa153e85a	\N	LOGIN_FAILED	users	\N	{}	2026-11-06 22:56:58.205572-05	FAILED	Intento de inicio de sesión fallido
badeaeac-3aaa-4f77-a1c5-dd7fb463ac50	\N	LOGIN_FAILED	users	\N	{}	2026-11-06 22:57:52.353097-05	FAILED	Intento de inicio de sesión fallido
11a4c3ab-0737-41db-bd80-3e1c22a63b1d	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	LOGIN	users	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	{}	2026-11-06 22:58:12.929273-05	SUCCESS	login
657d7041-7472-4b45-a269-d51250f9144e	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGOUT	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-11-06 22:59:31.677004-05	SUCCESS	Cierre de sesión
1d134292-c962-44f0-89b3-677c70a262f8	\N	LOGIN_FAILED	users	\N	{}	2026-11-06 22:59:38.033349-05	FAILED	Intento de inicio de sesión fallido
863dc299-bab0-4280-aea6-b3085fbfddea	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	LOGIN	users	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	{}	2026-11-06 22:59:42.13937-05	SUCCESS	login
1cccabc6-41ea-4ddf-adf2-cb0930d6380b	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	CHANGE_STATUS	service_orders	7b4a854d-825e-46e4-b401-9d6fad370dc3	{}	2026-11-06 23:00:23.292237-05	SUCCESS	change status
3958b11f-a336-4d00-8744-44701fb70a9f	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	SAVE_TECHNICAL_ATTENTION	technical_attentions	13f75d6e-024e-4e77-a1c0-20f02845ea54	{}	2026-11-06 23:05:15.034821-05	SUCCESS	Registro o actualización de atención técnica
43a121c9-a9b3-47f6-8627-f10767628588	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	FINALIZE_SERVICE_ORDER	service_orders	7b4a854d-825e-46e4-b401-9d6fad370dc3	{}	2026-11-06 23:05:15.065028-05	SUCCESS	finalize service order
be93b80c-bef1-447b-bd99-44319bf4a726	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	LOGOUT	users	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	{}	2026-11-06 23:05:53.092848-05	SUCCESS	Cierre de sesión
d6f9e8b0-b4f1-4ee7-8856-75c5cdc74140	ed8565ad-31a6-4bf7-bfaa-518602317906	LOGIN	users	ed8565ad-31a6-4bf7-bfaa-518602317906	{}	2026-11-06 23:06:38.015868-05	SUCCESS	login
c0b84818-3411-4908-9126-144031a669d2	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	LOGIN	users	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	{}	2026-11-07 12:49:22.691516-05	SUCCESS	login
\.


--
-- TOC entry 5316 (class 0 OID 17439)
-- Dependencies: 238
-- Data for Name: system_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.system_settings (key, value, updated_by, updated_at) FROM stdin;
\.


--
-- TOC entry 5310 (class 0 OID 17273)
-- Dependencies: 232
-- Data for Name: technical_attentions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.technical_attentions (id, order_id, technician_id, diagnosis, actions_performed, recommendations, started_at, finished_at, created_at, updated_at, performed_tests, parts_used, observations, result_summary, updated_by) FROM stdin;
0665c9c3-6098-4aa1-a787-4d313c938b32	4eac7b12-84dc-4176-bc51-2e1807855335	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	pantallazo azul del sistema operativo	se procedio a revisar el sistema y ver si se restaura		2026-10-18 00:00:00-05	2026-10-18 17:47:12.522959-05	2026-10-18 17:47:12.502693-05	2026-10-18 17:47:12.522959-05	se hizo el inicio con un mini sistema para realizar verificaciones		se procedio al cambio de disco duroi tambien se observo falta de mantenimeinto	se hizo el cambio del disco duro ya que era el responsable del problema ademas se hizo la nueva instalacion del sistema mas sus programas basicos en el disco	3b5b21e1-2d91-4a99-8eb6-37f67b06522b
13f75d6e-024e-4e77-a1c0-20f02845ea54	7b4a854d-825e-46e4-b401-9d6fad370dc3	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	Cabezal de impresion obstruido, suciedad en los rodillo y el los sensores del jalado del papel y pro ultimo escaner en deterioro	se hizo el lavado del cabezal de impresion, se procedio a dar mantenimiento interno a toda la impresora y se hizo el cambio de escaner		2026-11-06 00:00:00-05	2026-11-06 23:05:15.065028-05	2026-11-06 23:05:15.034821-05	2026-11-06 23:05:15.065028-05	se realizo impresiones a colores  con varios tipos de papel ademas de escanos a color y blanco y negro	escaner de impresora	efectura mantenimiento cada 6 meses de acuerdo a l uso	se soluciono correctamente el detalle que se registro ademas se verifico el contador de impresion y se resetio para que el cliente no tenga dificutades mas adelante	3b5b21e1-2d91-4a99-8eb6-37f67b06522b
\.


--
-- TOC entry 5308 (class 0 OID 17200)
-- Dependencies: 230
-- Data for Name: technician_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.technician_assignments (id, order_id, technician_id, assigned_by, assigned_at, ended_at, notes) FROM stdin;
963afc15-5060-44be-9c6e-0f20b0a5985a	4eac7b12-84dc-4176-bc51-2e1807855335	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	2026-10-18 13:46:46.968835-05	\N	
ab4a487c-5ee0-49f4-9029-91139fa1beaf	7b4a854d-825e-46e4-b401-9d6fad370dc3	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	ed8565ad-31a6-4bf7-bfaa-518602317906	2026-11-06 22:09:05.30923-05	\N	revision de manera obligatoria limpieza
822f6a54-cd4b-4721-a678-cc3781384070	e05a6517-c7d2-40a4-bfdc-8d27b085e5eb	3b5b21e1-2d91-4a99-8eb6-37f67b06522b	ed8565ad-31a6-4bf7-bfaa-518602317906	2026-11-06 22:09:19.308211-05	2026-11-06 22:10:55.42995-05	
c94de395-e31a-4dd5-857a-e939cdfb7c15	e05a6517-c7d2-40a4-bfdc-8d27b085e5eb	b31dd59d-f191-48a3-9970-7e3803b86707	ed8565ad-31a6-4bf7-bfaa-518602317906	2026-11-06 22:10:55.42995-05	\N	
\.


--
-- TOC entry 5301 (class 0 OID 17015)
-- Dependencies: 223
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, first_name, last_name, username, password_hash, role_code, active, created_at, updated_at) FROM stdin;
b06d57c8-b2a0-4ca2-8dd8-f2fd5f2a65b1	Administrador	Sistema	admin	$2a$12$qzpBtt0yUo3ExAhtkx5/f.MmiCGdVymwKJryoqlQYBWgrYjpIVvju	ADMINISTRADOR	t	2026-10-03 14:26:11.662849-05	2026-10-03 14:27:10.734237-05
3b5b21e1-2d91-4a99-8eb6-37f67b06522b	Erick Manuel	Ruiz Guerra	eruiz	$2a$12$OGQhx9QLUv1SRA4v7doTyegS8mTqPBy.k83kHihQzX7fAJXWTaMcq	TÉCNICO	t	2026-10-09 01:13:48.289292-05	2026-10-09 01:13:48.289292-05
a0c876e3-bec6-42b5-b41d-61820615ebf5	Practicas	Sistema	sis	$2a$12$a49GP9KThtnBdWingvNk..W3/qeaIPfkAJiejPcMmAhmDsxxzmFNG	PERSONAL DE ATENCIÓN	t	2026-10-31 20:50:56.043893-05	2026-10-31 20:50:56.043893-05
ed8565ad-31a6-4bf7-bfaa-518602317906	Usuario	tester	QA	$2a$12$XzvGh66PnZh3IhJ9UUZQX.KB7.lDyyOlfiozxLAXUkNS79eaM2PVS	ADMINISTRADOR	t	2026-10-31 20:50:18.297851-05	2026-10-31 20:53:52.546359-05
b31dd59d-f191-48a3-9970-7e3803b86707	Jean	Celiz Paredes	jceliz	$2a$12$SJVu.JFH/AM/9w.Nm3/2MOHBNe9AgwcxWrKAXtSD0qpCc2wDXF8YC	TÉCNICO	t	2026-10-03 18:52:39.099246-05	2026-11-06 22:10:39.870277-05
\.


--
-- TOC entry 5322 (class 0 OID 0)
-- Dependencies: 228
-- Name: service_order_number_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_order_number_seq', 4, true);


--
-- TOC entry 5088 (class 2606 OID 17330)
-- Name: ai_prediagnoses ai_prediagnoses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_prediagnoses
    ADD CONSTRAINT ai_prediagnoses_pkey PRIMARY KEY (id);


--
-- TOC entry 5092 (class 2606 OID 17361)
-- Name: ai_validations ai_validations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_validations
    ADD CONSTRAINT ai_validations_pkey PRIMARY KEY (id);


--
-- TOC entry 5094 (class 2606 OID 17363)
-- Name: ai_validations ai_validations_prediagnosis_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_validations
    ADD CONSTRAINT ai_validations_prediagnosis_id_key UNIQUE (prediagnosis_id);


--
-- TOC entry 5103 (class 2606 OID 17414)
-- Name: backup_runs backup_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.backup_runs
    ADD CONSTRAINT backup_runs_pkey PRIMARY KEY (id);


--
-- TOC entry 5007 (class 2606 OID 24577)
-- Name: clients clients_email_required_and_valid; Type: CHECK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.clients
    ADD CONSTRAINT clients_email_required_and_valid CHECK ((((email)::text = btrim((email)::text)) AND ((email)::text <> ''::text) AND ((email)::text ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'::text))) NOT VALID;


--
-- TOC entry 5009 (class 2606 OID 24576)
-- Name: clients clients_phone_nine_digits; Type: CHECK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.clients
    ADD CONSTRAINT clients_phone_nine_digits CHECK (((phone)::text ~ '^[0-9]{9}$'::text)) NOT VALID;


--
-- TOC entry 5055 (class 2606 OID 17074)
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- TOC entry 5058 (class 2606 OID 17105)
-- Name: equipment equipment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT equipment_pkey PRIMARY KEY (id);


--
-- TOC entry 5038 (class 2606 OID 16980)
-- Name: flyway_schema_history flyway_schema_history_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.flyway_schema_history
    ADD CONSTRAINT flyway_schema_history_pk PRIMARY KEY (installed_rank);


--
-- TOC entry 5106 (class 2606 OID 17437)
-- Name: monitoring_checks monitoring_checks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monitoring_checks
    ADD CONSTRAINT monitoring_checks_pkey PRIMARY KEY (id);


--
-- TOC entry 5082 (class 2606 OID 17250)
-- Name: order_status_history order_status_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_status_history
    ADD CONSTRAINT order_status_history_pkey PRIMARY KEY (id);


--
-- TOC entry 5065 (class 2606 OID 17131)
-- Name: order_status_transitions order_status_transitions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_status_transitions
    ADD CONSTRAINT order_status_transitions_pkey PRIMARY KEY (from_status, to_status);


--
-- TOC entry 5061 (class 2606 OID 17123)
-- Name: order_statuses order_statuses_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_statuses
    ADD CONSTRAINT order_statuses_name_key UNIQUE (name);


--
-- TOC entry 5063 (class 2606 OID 17121)
-- Name: order_statuses order_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_statuses
    ADD CONSTRAINT order_statuses_pkey PRIMARY KEY (code);


--
-- TOC entry 5045 (class 2606 OID 16997)
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (code);


--
-- TOC entry 5047 (class 2606 OID 17004)
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (role_code, permission_code);


--
-- TOC entry 5041 (class 2606 OID 16990)
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- TOC entry 5043 (class 2606 OID 16988)
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (code);


--
-- TOC entry 5069 (class 2606 OID 17175)
-- Name: service_orders service_orders_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_orders
    ADD CONSTRAINT service_orders_number_key UNIQUE (number);


--
-- TOC entry 5071 (class 2606 OID 17173)
-- Name: service_orders service_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_orders
    ADD CONSTRAINT service_orders_pkey PRIMARY KEY (id);


--
-- TOC entry 5101 (class 2606 OID 17390)
-- Name: system_events system_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_events
    ADD CONSTRAINT system_events_pkey PRIMARY KEY (id);


--
-- TOC entry 5109 (class 2606 OID 17449)
-- Name: system_settings system_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_settings
    ADD CONSTRAINT system_settings_pkey PRIMARY KEY (key);


--
-- TOC entry 5086 (class 2606 OID 17296)
-- Name: technical_attentions technical_attentions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.technical_attentions
    ADD CONSTRAINT technical_attentions_pkey PRIMARY KEY (id);


--
-- TOC entry 5078 (class 2606 OID 17216)
-- Name: technician_assignments technician_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.technician_assignments
    ADD CONSTRAINT technician_assignments_pkey PRIMARY KEY (id);


--
-- TOC entry 5049 (class 2606 OID 17035)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 5074 (class 1259 OID 17234)
-- Name: assignments_assigner_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX assignments_assigner_idx ON public.technician_assignments USING btree (assigned_by);


--
-- TOC entry 5075 (class 1259 OID 17232)
-- Name: assignments_one_current; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX assignments_one_current ON public.technician_assignments USING btree (order_id) WHERE (ended_at IS NULL);


--
-- TOC entry 5076 (class 1259 OID 17233)
-- Name: assignments_technician_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX assignments_technician_idx ON public.technician_assignments USING btree (technician_id, assigned_at);


--
-- TOC entry 5083 (class 1259 OID 17307)
-- Name: attentions_order_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX attentions_order_idx ON public.technical_attentions USING btree (order_id, created_at);


--
-- TOC entry 5084 (class 1259 OID 17308)
-- Name: attentions_technician_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX attentions_technician_idx ON public.technical_attentions USING btree (technician_id);


--
-- TOC entry 5104 (class 1259 OID 17420)
-- Name: backups_requester_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX backups_requester_idx ON public.backup_runs USING btree (requested_by);


--
-- TOC entry 5052 (class 1259 OID 17075)
-- Name: clients_document_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX clients_document_unique ON public.clients USING btree (lower((document_number)::text));


--
-- TOC entry 5053 (class 1259 OID 24578)
-- Name: clients_email_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX clients_email_unique ON public.clients USING btree (lower(btrim((email)::text))) WHERE (btrim((email)::text) <> ''::text);


--
-- TOC entry 5056 (class 1259 OID 17112)
-- Name: equipment_client_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX equipment_client_idx ON public.equipment USING btree (client_id);


--
-- TOC entry 5059 (class 1259 OID 17111)
-- Name: equipment_serial_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX equipment_serial_unique ON public.equipment USING btree (lower((serial_number)::text)) WHERE ((serial_number)::text <> ''::text);


--
-- TOC entry 5096 (class 1259 OID 17396)
-- Name: events_actor_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX events_actor_idx ON public.system_events USING btree (actor_id);


--
-- TOC entry 5097 (class 1259 OID 17397)
-- Name: events_date_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX events_date_idx ON public.system_events USING btree (occurred_at);


--
-- TOC entry 5098 (class 1259 OID 17398)
-- Name: events_entity_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX events_entity_idx ON public.system_events USING btree (entity_type, entity_id);


--
-- TOC entry 5099 (class 1259 OID 24606)
-- Name: events_result_date_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX events_result_date_idx ON public.system_events USING btree (result, occurred_at DESC);


--
-- TOC entry 5039 (class 1259 OID 16981)
-- Name: flyway_schema_history_s_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX flyway_schema_history_s_idx ON public.flyway_schema_history USING btree (success);


--
-- TOC entry 5107 (class 1259 OID 17438)
-- Name: monitoring_component_date_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX monitoring_component_date_idx ON public.monitoring_checks USING btree (component, checked_at);


--
-- TOC entry 5079 (class 1259 OID 17271)
-- Name: order_history_order_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX order_history_order_idx ON public.order_status_history USING btree (order_id, changed_at);


--
-- TOC entry 5080 (class 1259 OID 17272)
-- Name: order_history_user_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX order_history_user_idx ON public.order_status_history USING btree (changed_by);


--
-- TOC entry 5089 (class 1259 OID 17341)
-- Name: prediagnoses_order_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX prediagnoses_order_idx ON public.ai_prediagnoses USING btree (order_id, requested_at);


--
-- TOC entry 5090 (class 1259 OID 17342)
-- Name: prediagnoses_requester_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX prediagnoses_requester_idx ON public.ai_prediagnoses USING btree (requested_by);


--
-- TOC entry 5066 (class 1259 OID 17197)
-- Name: service_orders_client_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX service_orders_client_idx ON public.service_orders USING btree (client_id);


--
-- TOC entry 5067 (class 1259 OID 17196)
-- Name: service_orders_equipment_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX service_orders_equipment_idx ON public.service_orders USING btree (equipment_id);


--
-- TOC entry 5072 (class 1259 OID 17199)
-- Name: service_orders_receiver_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX service_orders_receiver_idx ON public.service_orders USING btree (received_by);


--
-- TOC entry 5073 (class 1259 OID 17198)
-- Name: service_orders_status_date_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX service_orders_status_date_idx ON public.service_orders USING btree (status_code, created_at);


--
-- TOC entry 5050 (class 1259 OID 17042)
-- Name: users_role_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX users_role_idx ON public.users USING btree (role_code);


--
-- TOC entry 5051 (class 1259 OID 17041)
-- Name: users_username_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX users_username_unique ON public.users USING btree (lower((username)::text));


--
-- TOC entry 5095 (class 1259 OID 17374)
-- Name: validations_technician_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX validations_technician_idx ON public.ai_validations USING btree (technician_id);


--
-- TOC entry 5144 (class 2620 OID 17458)
-- Name: technician_assignments assignment_technician; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER assignment_technician BEFORE INSERT OR UPDATE OF technician_id ON public.technician_assignments FOR EACH ROW EXECUTE FUNCTION public.validate_technician();


--
-- TOC entry 5145 (class 2620 OID 17459)
-- Name: technical_attentions attention_technician; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER attention_technician BEFORE INSERT OR UPDATE OF technician_id ON public.technical_attentions FOR EACH ROW EXECUTE FUNCTION public.validate_technician();


--
-- TOC entry 5139 (class 2620 OID 17465)
-- Name: clients clients_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER clients_updated_at BEFORE UPDATE ON public.clients FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- TOC entry 5140 (class 2620 OID 17466)
-- Name: equipment equipment_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER equipment_updated_at BEFORE UPDATE ON public.equipment FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- TOC entry 5141 (class 2620 OID 17462)
-- Name: service_orders order_transition; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER order_transition BEFORE UPDATE OF status_code ON public.service_orders FOR EACH ROW EXECUTE FUNCTION public.validate_status_transition();


--
-- TOC entry 5142 (class 2620 OID 17456)
-- Name: service_orders service_order_owner; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER service_order_owner BEFORE INSERT OR UPDATE OF equipment_id, client_id ON public.service_orders FOR EACH ROW EXECUTE FUNCTION public.validate_order_owner();


--
-- TOC entry 5143 (class 2620 OID 17467)
-- Name: service_orders service_orders_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER service_orders_updated_at BEFORE UPDATE ON public.service_orders FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- TOC entry 5148 (class 2620 OID 17469)
-- Name: system_settings system_settings_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER system_settings_updated_at BEFORE UPDATE ON public.system_settings FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- TOC entry 5146 (class 2620 OID 17468)
-- Name: technical_attentions technical_attentions_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER technical_attentions_updated_at BEFORE UPDATE ON public.technical_attentions FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- TOC entry 5138 (class 2620 OID 17464)
-- Name: users users_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- TOC entry 5147 (class 2620 OID 17460)
-- Name: ai_validations validation_technician; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER validation_technician BEFORE INSERT OR UPDATE OF technician_id ON public.ai_validations FOR EACH ROW EXECUTE FUNCTION public.validate_technician();


--
-- TOC entry 5131 (class 2606 OID 17331)
-- Name: ai_prediagnoses ai_prediagnoses_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_prediagnoses
    ADD CONSTRAINT ai_prediagnoses_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.service_orders(id) ON DELETE RESTRICT;


--
-- TOC entry 5132 (class 2606 OID 17336)
-- Name: ai_prediagnoses ai_prediagnoses_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_prediagnoses
    ADD CONSTRAINT ai_prediagnoses_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.users(id);


--
-- TOC entry 5133 (class 2606 OID 17364)
-- Name: ai_validations ai_validations_prediagnosis_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_validations
    ADD CONSTRAINT ai_validations_prediagnosis_id_fkey FOREIGN KEY (prediagnosis_id) REFERENCES public.ai_prediagnoses(id) ON DELETE RESTRICT;


--
-- TOC entry 5134 (class 2606 OID 17369)
-- Name: ai_validations ai_validations_technician_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_validations
    ADD CONSTRAINT ai_validations_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.users(id);


--
-- TOC entry 5136 (class 2606 OID 17415)
-- Name: backup_runs backup_runs_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.backup_runs
    ADD CONSTRAINT backup_runs_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.users(id);


--
-- TOC entry 5113 (class 2606 OID 17106)
-- Name: equipment equipment_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT equipment_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE RESTRICT;


--
-- TOC entry 5124 (class 2606 OID 17266)
-- Name: order_status_history order_status_history_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_status_history
    ADD CONSTRAINT order_status_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.users(id);


--
-- TOC entry 5125 (class 2606 OID 17256)
-- Name: order_status_history order_status_history_from_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_status_history
    ADD CONSTRAINT order_status_history_from_status_fkey FOREIGN KEY (from_status) REFERENCES public.order_statuses(code);


--
-- TOC entry 5126 (class 2606 OID 17251)
-- Name: order_status_history order_status_history_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_status_history
    ADD CONSTRAINT order_status_history_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.service_orders(id) ON DELETE RESTRICT;


--
-- TOC entry 5127 (class 2606 OID 17261)
-- Name: order_status_history order_status_history_to_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_status_history
    ADD CONSTRAINT order_status_history_to_status_fkey FOREIGN KEY (to_status) REFERENCES public.order_statuses(code);


--
-- TOC entry 5114 (class 2606 OID 17132)
-- Name: order_status_transitions order_status_transitions_from_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_status_transitions
    ADD CONSTRAINT order_status_transitions_from_status_fkey FOREIGN KEY (from_status) REFERENCES public.order_statuses(code);


--
-- TOC entry 5115 (class 2606 OID 17137)
-- Name: order_status_transitions order_status_transitions_to_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_status_transitions
    ADD CONSTRAINT order_status_transitions_to_status_fkey FOREIGN KEY (to_status) REFERENCES public.order_statuses(code);


--
-- TOC entry 5110 (class 2606 OID 17010)
-- Name: role_permissions role_permissions_permission_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_permission_code_fkey FOREIGN KEY (permission_code) REFERENCES public.permissions(code);


--
-- TOC entry 5111 (class 2606 OID 17005)
-- Name: role_permissions role_permissions_role_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_role_code_fkey FOREIGN KEY (role_code) REFERENCES public.roles(code);


--
-- TOC entry 5116 (class 2606 OID 17181)
-- Name: service_orders service_orders_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_orders
    ADD CONSTRAINT service_orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE RESTRICT;


--
-- TOC entry 5117 (class 2606 OID 17176)
-- Name: service_orders service_orders_equipment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_orders
    ADD CONSTRAINT service_orders_equipment_id_fkey FOREIGN KEY (equipment_id) REFERENCES public.equipment(id) ON DELETE RESTRICT;


--
-- TOC entry 5118 (class 2606 OID 24594)
-- Name: service_orders service_orders_finalized_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_orders
    ADD CONSTRAINT service_orders_finalized_by_fkey FOREIGN KEY (finalized_by) REFERENCES public.users(id);


--
-- TOC entry 5119 (class 2606 OID 17186)
-- Name: service_orders service_orders_received_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_orders
    ADD CONSTRAINT service_orders_received_by_fkey FOREIGN KEY (received_by) REFERENCES public.users(id);


--
-- TOC entry 5120 (class 2606 OID 17191)
-- Name: service_orders service_orders_status_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_orders
    ADD CONSTRAINT service_orders_status_code_fkey FOREIGN KEY (status_code) REFERENCES public.order_statuses(code);


--
-- TOC entry 5135 (class 2606 OID 17391)
-- Name: system_events system_events_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_events
    ADD CONSTRAINT system_events_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.users(id);


--
-- TOC entry 5137 (class 2606 OID 17450)
-- Name: system_settings system_settings_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_settings
    ADD CONSTRAINT system_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- TOC entry 5128 (class 2606 OID 17297)
-- Name: technical_attentions technical_attentions_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.technical_attentions
    ADD CONSTRAINT technical_attentions_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.service_orders(id) ON DELETE RESTRICT;


--
-- TOC entry 5129 (class 2606 OID 17302)
-- Name: technical_attentions technical_attentions_technician_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.technical_attentions
    ADD CONSTRAINT technical_attentions_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.users(id);


--
-- TOC entry 5130 (class 2606 OID 24589)
-- Name: technical_attentions technical_attentions_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.technical_attentions
    ADD CONSTRAINT technical_attentions_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- TOC entry 5121 (class 2606 OID 17227)
-- Name: technician_assignments technician_assignments_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.technician_assignments
    ADD CONSTRAINT technician_assignments_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.users(id);


--
-- TOC entry 5122 (class 2606 OID 17217)
-- Name: technician_assignments technician_assignments_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.technician_assignments
    ADD CONSTRAINT technician_assignments_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.service_orders(id) ON DELETE RESTRICT;


--
-- TOC entry 5123 (class 2606 OID 17222)
-- Name: technician_assignments technician_assignments_technician_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.technician_assignments
    ADD CONSTRAINT technician_assignments_technician_id_fkey FOREIGN KEY (technician_id) REFERENCES public.users(id);


--
-- TOC entry 5112 (class 2606 OID 17036)
-- Name: users users_role_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_code_fkey FOREIGN KEY (role_code) REFERENCES public.roles(code);


-- Completed on 2026-11-07 15:05:46

--
-- PostgreSQL database dump complete
--

\unrestrict GMYNRfHbwSaW6GEJhbfC8UHNumvQ0iTFWTHJFoxIJHbaHVHWhrP9aR8KyKxpnoj

