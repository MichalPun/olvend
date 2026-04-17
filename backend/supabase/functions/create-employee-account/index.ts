import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type CreateEmployeePayload = {
  name: string;
  surname: string;
  email: string;
  password: string;
  role: string;
  position?: string | null;
  phone?: string | null;
  note?: string | null;
  warehouse_id?: string | number | null;
  active?: boolean;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Missing Supabase environment variables." }, 500);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization header." }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const {
      data: { user: currentUser },
      error: currentUserError,
    } = await userClient.auth.getUser();

    if (currentUserError || !currentUser) {
      return json({ error: "Unauthorized user." }, 401);
    }

    const { data: currentEmployee, error: currentEmployeeError } = await adminClient
      .from("employees")
      .select("id, role, active")
      .eq("auth_user_id", currentUser.id)
      .maybeSingle();

    if (currentEmployeeError) {
      return json({ error: currentEmployeeError.message }, 400);
    }

    if (!currentEmployee || currentEmployee.active === false) {
      return json({ error: "Current user is not linked to an active employee." }, 403);
    }

    if (!["admin", "manager"].includes(String(currentEmployee.role ?? "").toLowerCase())) {
      return json({ error: "Only admin or manager can create employees." }, 403);
    }

    const payload = (await req.json()) as CreateEmployeePayload;

    if (!payload.name?.trim() || !payload.surname?.trim()) {
      return json({ error: "Name and surname are required." }, 400);
    }

    if (!payload.email?.trim() || !payload.password?.trim()) {
      return json({ error: "Email and password are required." }, 400);
    }

    if (!payload.role?.trim()) {
      return json({ error: "Role is required." }, 400);
    }

    const email = normalizeEmail(payload.email);

    const { data: existingEmployee } = await adminClient
      .from("employees")
      .select("id, email, auth_user_id")
      .eq("email", email)
      .maybeSingle();

    if (existingEmployee?.auth_user_id) {
      return json({ error: "Employee account already exists for this email." }, 409);
    }

    const { data: createdUser, error: createUserError } = await adminClient.auth.admin.createUser({
      email,
      password: payload.password,
      email_confirm: true,
      user_metadata: {
        name: payload.name.trim(),
        surname: payload.surname.trim(),
        role: payload.role.trim(),
      },
    });

    if (createUserError || !createdUser.user) {
      return json({ error: createUserError?.message ?? "Unable to create auth user." }, 400);
    }

    const employeePayload = {
      name: payload.name.trim(),
      surname: payload.surname.trim(),
      email,
      role: payload.role.trim(),
      position: payload.position?.trim() || null,
      phone: payload.phone?.trim() || null,
      note: payload.note?.trim() || null,
      warehouse_id: payload.warehouse_id || null,
      active: payload.active !== false,
      auth_user_id: createdUser.user.id,
      created_by: currentUser.id,
    };

    let employeeResult;

    if (existingEmployee?.id) {
      employeeResult = await adminClient
        .from("employees")
        .update(employeePayload)
        .eq("id", existingEmployee.id)
        .select("id, name, surname, email, role, auth_user_id, active")
        .single();
    } else {
      employeeResult = await adminClient
        .from("employees")
        .insert([employeePayload])
        .select("id, name, surname, email, role, auth_user_id, active")
        .single();
    }

    if (employeeResult.error) {
      await adminClient.auth.admin.deleteUser(createdUser.user.id);
      return json({ error: employeeResult.error.message }, 400);
    }

    return json({
      employee: employeeResult.data,
      auth_user_id: createdUser.user.id,
      message: "Employee account created successfully.",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown server error.";
    return json({ error: message }, 500);
  }
});
