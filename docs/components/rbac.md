# RBAC

## Feature List

### Back

- RBAC Database Schema — 4 таблицы: `rbac_roles` (id, name, slug, timestamps), `rbac_permissions` (id, name, slug, timestamps), `rbac_role_permissions` (role_id, permission_id — M:N связь), `rbac_user_roles` (user_id, role_id — M:N связь). Все с уникальными индексами на slug, составными unique constraints на join-таблицы и FK с CASCADE DELETE. Миграция `000003_create_rbac_tables.up.sql`.

- Seed-данные ролей и разрешений — 3 миграции: `000004_seed_rbac` (admin роль, 4 user CRUD permissions: user_add / user_edit / user_delete / user_view), `000005_seed_user_role_permissions` (3 permissions для управления ролями пользователей: user_role_add / user_role_view / user_role_delete), `000009_seed_data_rbac_roles` (data_permissions: data_view / data_add / data_edit / data_delete, роли Data Analytics и Data Operator, тестовый пользователь Ivan Data Worker с двумя ролями).

- RBAC Service Interface (`back/src/internal/pkg/services/rbac/service.go`) — полный CRUD через единый интерфейс: CreateRole / CreatePermission, AssignPermissionsToRole / AssignRoleToUser, CheckUserRole / CheckUserPermission / CheckRolePermission, RevokeUserRole / RevokeRolePermission, GetAllRoles / GetUserRoles / GetRolePermissions / GetAllPermissions, DeleteRole / DeletePermission с защитой от удаления занятых сущностей (ErrRoleInUse / ErrPermissionInUse). Идемпотентность повторного назначения permission роли.

- RBAC Service Implementation — 4 репозитория (RbacRole, RbacPermission, RbacRolePermission, RbacUserRole) на xo-генерированных типах. Wire DI провайдер (`provider.go`).

- Go-константы slugs — `back/src/internal/pkg/services/rbac/role/role.go`: Admin = "admin", DataAnalytics = "data_analytics", DataOperator = "data_operator". `back/src/internal/pkg/services/rbac/permission/permission.go`: UserAdd, UserEdit, UserDelete, UserView, UserRoleAdd, UserRoleView, UserRoleDelete, DataView, DataAdd, DataEdit, DataDelete.

- User Domain Authorization Decorator (`back/src/internal/app/goxus/domain/user/authorized_service.go`) — decorator pattern вокруг Service interface. Проверяет permission перед делегированием бизнес-логике: Create → user_add, List → user_view, GetByID → user_view (кроме self-read), Update → user_edit, UpdatePassword → user_edit, Delete → user_delete, Restore → user_delete, GetRoles → user_role_view, AssignRole → user_role_add, RevokeRole → user_role_delete, UploadAvatar/DeleteAvatar → user_edit. Public endpoints без RBAC: Login, Logout, ValidateToken, GetAvatar (публичный для <img>), DeleteExpiredTokens (внутренний cron).

- API Routes RBAC — GET /api/v1/roles (список всех ролей), GET /api/v1/entity/user/:id/roles (роли пользователя), POST /api/v1/entity/user/:id/roles (назначить роль, body: {role_slug}), DELETE /api/v1/entity/user/:id/roles/:slug (отозвать роль). Все routes требуют Bearer-аутентификацию. Хендлеры в `back/src/internal/app/goxus/api/server/router/v1/handlers/handlers.user.go`.

- UserWithRole View — миграция `000008_create_user_with_roles_view`: представление, объединяющее users + rbac_user_roles + rbac_roles через LEFT JOIN с `string_agg(r.name, ', ')`. Позволяет получать роли пользователя без N+1 запроса при списке пользователей. Тип `UserWithRole` в xo-генерации.

- RBAC Service Tests — `service_test.go`: 28+ тестов покрывают весь CRUD — создание, дубликаты, назначение permission роли, назначение роли пользователю, проверка разрешений (true/false/not-found), отзыв роли/permission, удаление с защитой in-use, идемпотентность, пустые списки. 97.3% coverage. testcontainers-based интеграционные тесты с PostgreSQL.

- User Domain Authorization Tests — `authorized_service_test.go`: тесты decorator-слоя с `grantPermission()` хелпером, который создает permission + роль + назначает роль актору. Покрывает access denied для каждого guarded метода.

### Front

- TypeScript constants для roles и permissions — `front/src/lib/role.ts`: константы Role.Admin / .DataAnalytics / .DataOperator с suggested Lucide icons. Интерфейсы RbacRole / RolesResponse. `front/src/lib/permission.ts`: Permission constants (11 slugs, зеркально backend). Все через `as const` для type-safe.

- API service roles (`front/src/lib/role.ts`) — fetchAllRoles() GET /api/v1/roles, fetchUserRoles(userId) GET /api/v1/entity/user/:id/roles, assignUserRole(userId, roleSlug) POST с JSON {role_slug}, revokeUserRole(userId, roleSlug) DELETE. Используют apiFetchJSON + getToken. AbortSignal-ready.

- Roles Management Dialog (`front/src/app/(dashboard)/users/roles-dialog.tsx`) — модальный диалог для управления ролями пользователя. Загружает все роли и текущие роли пользователя при открытии. Checkbox-интерфейс с dirty-трекингом — отправляет только измененные роли при сохранении. Визуальная дифференциация ролей: ShieldCheck/серый — admin, BarChart3/синий — data_analytics, Database/зеленый — data_operator. Состояния загрузки, сохранения, пустого списка.

- Users Table с отображением ролей (`front/src/app/(dashboard)/users/page.tsx`) — колонка "Roles" в таблице пользователей с цветными Badge (ShieldCheck/серый, BarChart3/синий, Database/зеленый). Роли парсятся из строки UserWithRole.Roles (string_agg через запятую).

- Role Filter Popover — Popover с Checkbox-фильтром по ролям в заголовке таблицы. Выбранные роли отображаются в кнопке триггера. Фильтр хранится в URL (query param `roles`). Поиск происходит на стороне фронта по полю roles строки.

- User Action Dropdown — DropdownMenu в каждой строке таблицы с действиями: Edit, Roles (открывает RolesDialog), Change Password, Delete/Restore. Roles action использует shield icon.

- URL-backed state persistence — все фильтры (q, status, email, roles, page, pageSize) хранятся в URLSearchParams. localStorage fallback для сохранения состояния между сессиями. Применяется sidebar/header (синтетический StorageEvent).

## How to

### Create Permission

1. Добавить константу slug в `back/src/internal/pkg/services/rbac/permission/permission.go`:

   ```go
   const (
       // ... existing permissions
       NewPermission = "new_permission"
   )
   ```

2. Создать миграцию `back/src/scripts/xo/goxus/migrations/`:

   ```bash
   cd back/src/scripts/xo
   bash migrate-new.sh ./goxus/migrations
   # ввести имя: seed_new_permission
   ```

3. Заполнить `.up.sql` — вставка permission + связь с нужными ролями (если нужно):

   ```sql
   -- UP: create new permission and link to admin role
   INSERT INTO public.rbac_permissions (name, slug)
   VALUES ('New Permission', 'new_permission')
   ON CONFLICT (slug) DO NOTHING;

   INSERT INTO public.rbac_role_permissions (role_id, permission_id)
   SELECT r.id, p.id
   FROM public.rbac_roles r
   CROSS JOIN public.rbac_permissions p
   WHERE r.slug = 'admin'
     AND p.slug = 'new_permission'
   ON CONFLICT (role_id, permission_id) DO NOTHING;
   ```

4. Заполнить `.down.sql` — очистка в обратном порядке (link → permission):

   ```sql
   -- DOWN: remove permission links, then delete permission
   DELETE FROM public.rbac_role_permissions
   WHERE permission_id = (SELECT id FROM public.rbac_permissions WHERE slug = 'new_permission');

   DELETE FROM public.rbac_permissions
   WHERE slug = 'new_permission';
   ```

5. Применить миграцию:

   ```bash
   cd back/src/scripts/xo
   bash migrate-up.sh goxus/xo.yaml
   ```

6. **(Программный вариант)** Создать permission через RBAC-сервис — без миграции, через код:

   ```go
   err := rbacSvc.CreatePermission("New Permission", "new_permission")
   // err == nil — создан, err == ErrAlreadyExists — уже существует
   ```

### Create Role with Permissions

1. Добавить константу slug в `back/src/internal/pkg/services/rbac/role/role.go`:

   ```go
   const (
       // ... existing roles
       NewRole = "new_role"
   )
   ```

2. Создать миграцию (как описано выше), `.up.sql`:

   ```sql
   -- UP: create role, link permissions
   INSERT INTO public.rbac_roles (name, slug)
   VALUES ('New Role', 'new_role')
   ON CONFLICT (slug) DO NOTHING;

   INSERT INTO public.rbac_role_permissions (role_id, permission_id)
   SELECT r.id, p.id
   FROM public.rbac_roles r
   CROSS JOIN public.rbac_permissions p
   WHERE r.slug = 'new_role'
     AND p.slug IN ('user_view', 'data_view')
   ON CONFLICT (role_id, permission_id) DO NOTHING;
   ```

   `.down.sql`:

   ```sql
   -- DOWN: clean role-permission links, then delete role
   DELETE FROM public.rbac_role_permissions
   WHERE role_id = (SELECT id FROM public.rbac_roles WHERE slug = 'new_role');

   DELETE FROM public.rbac_roles
   WHERE slug = 'new_role';
   ```

3. Применить миграцию:

   ```bash
   cd back/src/scripts/xo
   bash migrate-up.sh goxus/xo.yaml
   ```

4. **(Программный вариант)** Через RBAC-сервис:

   ```go
   // Создать роль
   err := rbacSvc.CreateRole("New Role", "new_role")

   // Назначить permission-ы
   err = rbacSvc.AssignPermissionsToRole("new_role", []string{"user_view", "data_view"})

   // Проверить связь
   hasPerm, _ := rbacSvc.CheckRolePermission("new_role", "user_view") // true
   ```

### Create User Roles (назначить роль пользователю)

1. **Через API (из фронтенда):**

   ```http
   POST /api/v1/entity/user/:id/roles
   Authorization: Bearer <token>
   Content-Type: application/json

   { "role_slug": "admin" }
   ```

   Требует permission `user_role_add` у текущего пользователя.

2. **Отозвать роль:**

   ```http
   DELETE /api/v1/entity/user/:id/roles/admin
   Authorization: Bearer <token>
   ```

   Требует permission `user_role_delete`.

3. **Через RBAC-сервис (из Go-кода или тестов):**

   ```go
   // Назначить роль
   err := rbacSvc.AssignRoleToUser(userID, "admin")
   // err == ErrAlreadyExists — если роль уже назначена

   // Проверить, что роль назначена
   hasRole, _ := rbacSvc.CheckUserRole(userID, "admin") // true/false

   // Проверить, что у пользователя есть permission через роль
   hasPerm, _ := rbacSvc.CheckUserPermission(userID, "user_add") // true/false

   // Отозвать роль
   err = rbacSvc.RevokeUserRole(userID, "admin")
   // если роль не была назначена — no-op, без ошибки
   ```

4. **Через миграцию** (например, для seed-пользователя при развертывании):

   ```sql
   INSERT INTO public.rbac_user_roles (user_id, role_id)
   SELECT u.id, r.id
   FROM public.users u
   CROSS JOIN public.rbac_roles r
   WHERE u.email = 'user@example.com'
     AND r.slug = 'admin'
   ON CONFLICT (user_id, role_id) DO NOTHING;
   ```

5. **Проверить текущие роли пользователя:**

   ```http
   GET /api/v1/entity/user/:id/roles
   Authorization: Bearer <token>
   ```

   ```go
   roles, _ := rbacSvc.GetUserRoles(userID) // []*goxus.RbacRole
   allRoles, _ := rbacSvc.GetAllRoles()     // все роли в системе
   ```
