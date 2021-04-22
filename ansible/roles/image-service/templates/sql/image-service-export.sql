--  Function used for full DB exports
CREATE OR REPLACE FUNCTION export_images() RETURNS void AS $$
    BEGIN
        COPY  
        (
            select
            data_resource_uid AS "dataResourceUid",
            occurrence_id as "occurrenceID",
            CONCAT( '{{image_service_base_url}}{{image_service_context_path}}/image/proxyImageThumbnailLarge?imageId=', image_identifier) AS identifier,
            regexp_replace(creator, E'[\\n\\r]+', ' ', 'g' ) AS creator,
            date_taken AS created,
            regexp_replace(title, E'[\\n\\r]+', ' ', 'g' ) AS title,
            mime_type AS format,
            regexp_replace(license, E'[\\n\\r]+', ' ', 'g' ) AS license,
            regexp_replace(rights, E'[\\n\\r]+', ' ', 'g' ) AS rights,
            regexp_replace(rights_holder, E'[\\n\\r]+', ' ', 'g' ) AS "rightsHolder",
            CONCAT('{{image_service_base_url}}{{image_service_context_path}}/image/', image_identifier) AS "references",
            regexp_replace(title, E'[\\n\\r]+', ' ', 'g' ) as title,
            regexp_replace(description, E'[\\n\\r]+', ' ', 'g' ) as description,
            extension as extension,
            l.acronym  as "recognisedLicense",
            i.date_deleted as "dateDeleted",
            contentmd5hash as md5hash,
            file_size as "fileSize",
            width as width,
            height as height,
            zoom_levels as "zoomLevels",
            image_identifier as "imageIdentifier"
            from image i
            left outer join license l ON l.id = i.recognised_license_id
            order by data_resource_uid
        )
        TO '{{image_service_export_dir | default('/data/image-service/exports')}}/images.csv' DELIMITER ',' CSV HEADER;
    END;
$$ LANGUAGE plpgsql;

--  Function used for regeneration of elastic search index
CREATE OR REPLACE FUNCTION export_index() RETURNS void AS $$
BEGIN
    COPY
        (
        select
            image_identifier as "imageIdentifier",
            contentmd5hash as "contentmd5hash",
            contentsha1hash as "contentsha1hash",
            mime_type AS format,
            original_filename AS originalFilename,
            extension as extension,
            TO_CHAR(date_uploaded :: DATE, 'yyyy-mm-dd') AS "dateUploaded",
            TO_CHAR(date_taken :: DATE, 'yyyy-mm-dd') AS created,
            file_size as "fileSize",
            height as height,
            width as width,
            zoom_levels as "zoomLevels",
            data_resource_uid AS "dataResourceUid",
            regexp_replace(regexp_replace(creator, '[|''"&]+',''), E'[\\n\\r]+', ' ', 'g' ) AS creator,
            regexp_replace(regexp_replace(title, '[|''"&]+',''), E'[\\n\\r]+', ' ', 'g' ) AS title,
            regexp_replace(regexp_replace(description, '[|''"&]+',''), E'[\\n\\r]+', ' ', 'g' )  AS description,
            regexp_replace(regexp_replace(rights, '[|''"&]+',''), E'[\\n\\r]+', ' ', 'g' )  AS rights,
            regexp_replace(regexp_replace(rights_holder, '[|''"&]+',''), E'[\\n\\r]+', ' ', 'g' )  AS "rightsHolder",
            regexp_replace(regexp_replace(license, '[|''"&]+',''), E'[\\n\\r]+', ' ', 'g' )  AS license,
            thumb_height AS "thumbHeight",
            thumb_width AS "thumbWidth",
            harvestable,
            l.acronym  as "recognisedLicence",
            occurrence_id AS "occurrenceID",
            audience AS "audience",
            source AS "source",
            contributor AS "contributor",
            type AS "type",
            created AS "created",
            dc_references AS "references",
            TO_CHAR(date_uploaded :: DATE, 'yyyy-mm') AS "dateUploadedYearMonth"
        from image i
            left outer join license l ON l.id = i.recognised_license_id
        where date_deleted is NULL and is_duplicate_of_id is NULL
        )
        TO '{{image_service_export_dir | default('/data/image-service/exports') }}/images-index.csv' WITH CSV DELIMITER '$' HEADER;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION export_dataset(uid varchar) RETURNS void AS $$
DECLARE
    output_file CONSTANT varchar := CONCAT(CONCAT( '{{ image_service_export_dir | default('/data/image-service/exports') }}/images-export-', uid), '.csv');
BEGIN
    EXECUTE format ('
    COPY
        (
        select
            i.image_identifier as "imageID",
            NULLIF(regexp_replace(i.original_filename, ''\\P{Cc}\\P{Cn}\\P{Cs}\\P{Cf}'',  '''', ''g''), '''')  AS  "identifier",
            NULLIF(regexp_replace(i.audience,          ''\\P{Cc}\\P{Cn}\\P{Cs}\\P{Cf}'',  '''', ''g''), '''')  AS  "audience",
            NULLIF(regexp_replace(i.contributor,       ''\\P{Cc}\\P{Cn}\\P{Cs}\\P{Cf}'',  '''', ''g''), '''')  AS  "contributor",
            NULLIF(regexp_replace(i.created,           ''\\P{Cc}\\P{Cn}\\P{Cs}\\P{Cf}'',  '''', ''g''), '''')  AS  "created",
            NULLIF(regexp_replace(i.creator,           ''\\P{Cc}\\P{Cn}\\P{Cs}\\P{Cf}'',  '''', ''g''), '''')  AS  "creator",
            NULLIF(regexp_replace(i.description,       ''\\P{Cc}\\P{Cn}\\P{Cs}\\P{Cf}'',  '''', ''g''), '''')  AS  "description",
            NULLIF(regexp_replace(i.mime_type,         ''\\P{Cc}\\P{Cn}\\P{Cs}\\P{Cf}'',  '''', ''g''), '''')  AS  "format",
            NULLIF(regexp_replace(i.license,           ''\\P{Cc}\\P{Cn}\\P{Cs}\\P{Cf}'',  '''', ''g''), '''')  AS  "license",
            NULLIF(regexp_replace(i.publisher,         ''\\P{Cc}\\P{Cn}\\P{Cs}\\P{Cf}'',  '''', ''g''), '''')  AS  "publisher",
            NULLIF(regexp_replace(i.dc_references,     ''\\P{Cc}\\P{Cn}\\P{Cs}\\P{Cf}'',  '''', ''g''), '''')  AS  "references",
            NULLIF(regexp_replace(i.rights_holder,     ''\\P{Cc}\\P{Cn}\\P{Cs}\\P{Cf}'',  '''', ''g''), '''')  AS  "rightsHolder",
            NULLIF(regexp_replace(i.source,            ''\\P{Cc}\\P{Cn}\\P{Cs}\\P{Cf}'',  '''', ''g''), '''')  AS  "source",
            NULLIF(regexp_replace(i.title,             ''\\P{Cc}\\P{Cn}\\P{Cs}\\P{Cf}'',  '''', ''g''), '''')  AS  "title",
            NULLIF(regexp_replace(i.type,              ''\\P{Cc}\\P{Cn}\\P{Cs}\\P{Cf}'',  '''', ''g''), '''')  AS  "type",
            i.is_duplicate_of_id
            from image i
            where i.data_resource_uid = %L
        )
    TO %L (FORMAT CSV, ESCAPE ''\'', ENCODING ''UTF8'')'
        , uid, output_file);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION export_dataset_mapping(uid varchar) RETURNS void AS $$
DECLARE
    output_file CONSTANT varchar := CONCAT(CONCAT( '{{image_service_export_dir | default('/data/image-service/exports') }}/images-mapping-', uid), '.csv');
BEGIN
    EXECUTE format ('
    COPY
        (
        select
            image_identifier as "imageID",
            original_filename as "url"
            from image i
            where data_resource_uid = %L
        )
    TO %L (FORMAT CSV)'
        , uid, output_file);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION export_mapping() RETURNS void AS $$
DECLARE
    output_file CONSTANT varchar :=  '{{image_service_export_dir | default('/data/image-service/exports') }}/images-mapping.csv';
BEGIN
    EXECUTE format ('
    COPY
        (
        select
            data_resource_uid,
            image_identifier as "imageID",
            original_filename as "url"
            from image i
            where data_resource_uid is NOT NULL
        )
    TO %L (FORMAT CSV)'
        , output_file);
END;
$$ LANGUAGE plpgsql;
