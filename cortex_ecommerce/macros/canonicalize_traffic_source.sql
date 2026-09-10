{% macro canonicalize_traffic_source(column_name) %}

    case
        when lower(trim({{ column_name }})) in ('search', 'adwords')
            then 'Search'

        when lower(trim({{ column_name }})) in ('display', 'youtube')
            then 'Display'

        when lower(trim({{ column_name }})) = 'facebook'
            then 'Facebook'

        when lower(trim({{ column_name }})) = 'email'
            then 'Email'

        when lower(trim({{ column_name }})) = 'organic'
            then 'Organic'

        when {{ column_name }} is null
            then 'Unknown'

        else initcap(trim({{ column_name }}))
    end

{% endmacro %}