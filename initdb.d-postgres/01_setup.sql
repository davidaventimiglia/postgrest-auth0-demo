-- -*- sql-product: postgres; -*-

create role anonymous with nosuperuser inherit nocreaterole nocreatedb nologin noreplication nobypassrls;

create role authenticator with nosuperuser noinherit nocreaterole nocreatedb nologin noreplication nobypassrls;

create schema if not exists core;

create extension if not exists xml2 with schema public;

create table core.param (
		id integer primary key generated always as identity,
		name text unique,
		val text
);

create or replace view resource as
	select
		oid,
		((obj_description(oid, 'pg_largeobject'::name))::jsonb ->> 'name'::text) as slug,
		(encode(lo_get(oid), 'escape'::text))::xml as content
		from pg_largeobject_metadata
	 where true
		 and obj_description(oid, 'pg_largeobject'::name)::jsonb->>'content-type' not in ('image/jpeg');

create or replace function index ()
	returns text
	language sql
	stable parallel safe
as $function$
	select
	xslt_process(
	xmlroot(
		xmlconcat(
			xmlpi(
				name "xml-stylesheet",
				format('href="%s" type="text/xsl"', (select val from core.param where name = 'xml-stylesheet'))),
				xmlelement(
					name index,
					xmlelement(
						name request,
						xmlelement(
							name headers,
							current_setting('request.headers', true)::json),
							xmlelement(
								name claims,
								current_setting('request.jwt.claims', true)::json),
								xmlelement(
									name cookies,
									current_setting('request.cookies', true)::json),
									xmlelement(
										name path,
										current_setting('request.path', true)),
										xmlelement(
											name method,
											current_setting('request.method', true))
					))), version '1.0', standalone yes)::text, content::text)
	from resource where slug = 'demo.xsl';
	$function$;

grant select on all tables in schema core to anonymous;

grant select on all tables in schema public to anonymous;

grant usage on schema core, public to anonymous;

notify pgrst, 'reload schema';
