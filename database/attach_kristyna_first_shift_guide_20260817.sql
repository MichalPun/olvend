update public.daily_instructions
set attachment_url = 'https://olvend.onrender.com/docs/OLVEND_prvni_smena_Kristyna_Dvorakova_2026-08-17.pdf',
    attachment_label = 'Otevřít návod pro první směnu',
    updated_at = now()
where source_reference = 'mandatory-fefo:2026-08-17:employee:9133f82b-89a6-4581-955c-d2138b947a8d';

select id, title, target_employee_id, valid_from, attachment_label, attachment_url
from public.daily_instructions
where source_reference = 'mandatory-fefo:2026-08-17:employee:9133f82b-89a6-4581-955c-d2138b947a8d';
