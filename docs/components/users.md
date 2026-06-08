# Users

# Feature List

### Back

- **User CRUD**

  Полноценное управление пользователями: создание (с именем, email, паролем), чтение по ID, обновление (имя, email), мягкое удаление (устанавливает `deleted_at`) и восстановление (снимает `deleted_at`). Каждая операция защищена отдельным RBAC-разрешением (`user_add`, `user_view`, `user_edit`, `user_delete`).

- **User Authentication (Login/Logout)**

  Аутентификация по email + пароль. При успехе создаётся UUID v4 токен в таблице `users_tokens`, который возвращается клиенту. Logout — мягкое удаление токена (устанавливает `deleted_at`). Пароль на данном этапе хранится в открытом виде (TODO: хеширование).

- **Bearer Token Middleware**

  Auth-middleware на всех защищённых endpoint'ах: находит токен в `Authorization: Bearer <token>`, проверяет что он не мягко удалён, находит связанного пользователя, проверяет что пользователь не мягко удалён, обновляет `last_used_at`. При невалидности — 401 Unauthorized.

- **Password Change**

  Изменение пароля любого пользователя. Требует RBAC-разрешения `user_edit`. Доступно только авторизованным администраторам — сам пользователь не может сменить свой пароль через UI (это операция администрирования).

- **User Restore (Soft-Delete Inverse)**

  Восстанавливает мягко удалённого пользователя — очищает `deleted_at`. Требует разрешения `user_delete` (то же, что и для удаления). Защита от повторного восстановления: пользователь должен быть именно в состоянии "удалён".

- **User Roles Management (Get / Assign / Revoke)**

  Получение списка ролей пользователя, назначение новой роли (по slug), отзыв роли. Каждая операция защищена отдельным разрешением (`user_role_view`, `user_role_add`, `user_role_delete`). Перед назначением/отзывом проверяется существование пользователя.

- **Role Listing**

  `GET /api/v1/roles` — возвращает все доступные роли в системе. Используется на фронтенде для построения фильтра по ролям и диалога управления ролями.

- **User Listing with Pagination**

  Список всех пользователей с пагинацией (`limit`, `offset`) и общим количеством (`total_count`). Использует представление `user_with_roles`, которое агрегирует имена ролей в строку через запятую — один запрос вместо N+1. Дефолтный размер страницы: 100 000.

- **Avatar System (Upload / Get / Delete)**

  Полноценная система аватаров: загрузка через multipart/form-data ("avatar" field), получение (публичный endpoint, без аутентификации — для `<img>` тегов), удаление. Аватары хранятся на файловой системе как `user-avatar-{id}.webp`. Размер строго 460×460 пикселей. При запросе отсутствующего пользовательского аватара возвращается дефолтный: сначала с диска, если нет — встроенный в бинарник (embedded via `//go:embed`), лениво записываемый на диск при первом запросе.

- **Avatar Validation**

  Загружаемые изображения проходят валидацию: декодирование через Go image-декодер (поддерживаются JPEG, PNG, GIF, WebP), проверка что размер ровно 460×460. Ошибки: `ErrInvalidImageFormat` (не декодируется) и `ErrInvalidImageSize` (не совпадает размер).

- **RBAC Authorization Decorator**

  Архитектурный паттерн: чистый сервис бизнес-логики (`impl`) обёрнут в авторизационный декоратор (`authorizedService`). Декоратор проверяет RBAC-разрешения перед делегированием. Публичные операции (Login, Logout, ValidateToken, GetAvatar, DeleteExpiredTokens) проходят без проверки. Self-read (actorID == id) на GetByID — без проверки.

- **Cannot Delete Self**

  Бизнес-правило: пользователь не может удалить сам себя. Проверка в декораторе — если `actorID == id`, возвращается `ErrCannotDeleteSelf`.

- **Duplicate Email Prevention**

  При создании и обновлении пользователя проверяется уникальность email — в том числе среди мягко удалённых пользователей (чтобы предотвратить коллизии при восстановлении).

- **Token Cleanup Cron Job**

  Системная cron-задача (по расписанию, по умолчанию каждый час), которая удаляет истёкшие токены из таблицы `users_tokens`. TTL настраивается в конфиге (по умолчанию 7 дней с `last_used_at`). Без RBAC-проверки — внутренняя операция.

- **Login Rate Limiting**

  In-memory sliding-window rate limiter на endpoint `POST /api/v1/auth/login`. Ключ — IP-адрес клиента. При превышении лимита возвращает 429 Too Many Requests с заголовком `Retry-After`.

### Front

- **Users Data Table**

  Полноценная таблица с колонками: аватар (иконка/initials), имя, email (с иконкой верификации — зелёная галочка / оранжевые часы), дата создания, роли (цветные badge с иконками). Аватар отображается как `<AvatarImage>` с `<AvatarFallback>` (первая буква имени). Строки мягко удалённых пользователей полупрозрачны.

- **Add User Dialog**

  Модальный диалог создания пользователя: поля name, email, password, confirm password (с валидацией через Zod — обязательные поля, email-формат, пароль ≥6 символов, совпадение паролей). Опциональная загрузка аватара через `AvatarDropZone` (drag-and-drop). После создания пользователя аватар загружается отдельным запросом.

- **Edit User Dialog**

  Модальный диалог редактирования пользователя: поля name, email (предзаполнены). Возможность загрузить новый аватар или удалить существующий. Аватар отображается с cache-busting (`&v=timestamp`).

- **Change Password Dialog**

  Диалог смены пароля: поля New Password и Confirm Password с Zod-валидацией. Вызывается из контекстного меню на строке пользователя.

- **Roles Management Dialog**

  Диалог управления ролями пользователя: загружает список всех ролей и текущие роли пользователя. Чекбоксы для назначения/отзыва — изменения отслеживаются как dirty-set и применяются пакетно при Save. Иконки ролей с цветовой маркировкой (admin — нейтральный, data_analytics — синий, data_operator — зелёный).

- **Soft Delete Dialog**

  Диалог подтверждения удаления пользователя с кнопками Cancel и Delete (destructive style). Показывается только для активных пользователей, не равных текущему администратору.

- **User Restore via Context Menu**

  В контекстном меню (DropdownMenu) строки мягко удалённого пользователя показывается пункт Restore (с иконкой RotateCcw). Выполняет `POST /api/v1/entity/user/:id/restore` и обновляет строку в таблице через `setAllUsers`.

- **Text Search**

  Поле поиска с иконкой лупы — фильтрация по имени и email (case-insensitive). Состояние сохраняется в URL search param `?q=`. При вводе сбрасывается номер страницы.

- **Status Filter Tabs**

  Три вкладки: All | Active | Deleted. Фильтрует по `deleted_at`. Сохраняется в URL как `?status=active|deleted`. Привязана к Tabs-компоненту из shadcn.

- **Email Verified Filter Tabs**

  Три вкладки: All | Verified | Unverified. Фильтрует по `email_verified_at`. Сохраняется в URL как `?email=verified|unverified`. Вторая группа Tabs на панели инструментов.

- **Role Filter Popover**

  Popover с чекбоксами для всех доступных ролей. Множественный выбор — комбинируется как OR-фильтр: пользователь с любой из выбранных ролей показывается. Выбранные роли отображаются как badge на кнопке-триггере. Кнопка "Clear filter" для сброса. Сохраняется в URL как `?roles=role1,role2`.

- **Pagination with Custom Page Size**

  Нижняя панель пагинации (`DataTablePagination`): номера страниц, выбор размера страницы (10/20/50/100), общее количество страниц. Состояние в URL: `?page=N&pageSize=N`. При изменении фильтра или поиска страница сбрасывается на 0.

- **URL-Backed Filter State**

  Все фильтры (поиск, статус, верификация email, роли, пагинация) хранятся в URL search params. Это позволяет: возвращаться к предыдущему состоянию через браузерный Back, ссылаться на отфильтрованный список, совмещать фильтры в одной ссылке.

- **localStorage Filter Persistence**

  При первом посещении страницы без URL-фильтров восстанавливает последние фильтры из `localStorage` (ключ `goxus_users_query`). Каждое изменение фильтра синхронизируется обратно в localStorage. Синтетическое событие `StorageEvent` уведомляет другие компоненты (сайдбар, хедер) об изменении.

- **Nav Link Filter Persistence**

  Ссылки на Users в сайдбаре и хедере автоматически включают текущие filter params из URL. При переходе на Dashboard и обратно фильтры сохраняются — ссылка на Users всегда ведёт к последнему фильтрованному состоянию.

- **Avatar Display in Table & Dialogs**

  Аватар пользователя отображается: (1) в первой колонке таблицы; (2) в диалоге редактирования/создания с возможностью загрузить/сменить/удалить. Cache-busting через `?t=timestamp` в таблице и `&v=timestamp` в диалоге. Fallback — первая буква имени пользователя.

- **Loading State**

  Skeleton-загрузка: пока данные загружаются, таблица отображает 5 строк-скелетонов с анимированным shimmer-эффектом.

- **Error State**

  При ошибке загрузки отображается сообщение об ошибке с кнопкой Retry. Если ошибка содержит "Not Found", "401" или "Not Authenticated" — токен очищается, и происходит редирект на /login.

- **Empty State**

  Когда пользователи не найдены: при активном поиске — "No users match your search.", без поиска — "No users found.".

## How to

### Create User

1. **Создайте новую миграцию:**
   ```bash
   cd back
   ./src/scripts/xo/migrate-new.sh ./src/scripts/xo/goxus/migrations
   # Введите имя: seed_john_doe
   ```
   Будут созданы: `000017_seed_john_doe.up.sql` и `000017_seed_john_doe.down.sql`.

2. **Up-миграция** (`000017_seed_john_doe.up.sql`):
   ```sql
   INSERT INTO public.users (name, email, password, email_verified_at)
   VALUES ('John Doe', 'john@example.com', 'secret', NOW());
   ```

3. **Down-миграция** (`000017_seed_john_doe.down.sql`):
   ```sql
   DELETE FROM public.users WHERE email = 'john@example.com';
   ```

4. **Примените:**
   ```bash
   cd back
   ./src/scripts/xo/migrate-up.sh
   ```

   Для отката:
   ```bash
   ./src/scripts/xo/migrate-down.sh
   ```

### Create User Roles

Роли создаются через миграции БД (golang-migrate) или RBAC-сервис. Основной способ — миграции:

1. **Создайте новую миграцию** (в `back/src/scripts/xo/goxus/migrations/`):
   ```bash
   cd back
   ./src/scripts/xo/migrate-new.sh ./src/scripts/xo/goxus/migrations
   # Введите имя: seed_my_new_roles
   ```
   Будут созданы два файла: `000017_seed_my_new_roles.up.sql` и `000017_seed_my_new_roles.down.sql`.

2. **Напишите up-миграцию** (`000017_seed_my_new_roles.up.sql`):
   ```sql
   -- 1. Create permissions
   INSERT INTO public.rbac_permissions (name, slug)
   VALUES ('Data Export', 'data_export')
   ON CONFLICT (slug) DO NOTHING;

   -- 2. Create role
   INSERT INTO public.rbac_roles (name, slug)
   VALUES ('Data Exporter', 'data_exporter')
   ON CONFLICT (slug) DO NOTHING;

   -- 3. Link permission to role
   INSERT INTO public.rbac_role_permissions (role_id, permission_id)
   SELECT r.id, p.id
   FROM public.rbac_roles r
            CROSS JOIN public.rbac_permissions p
   WHERE r.slug = 'data_exporter'
     AND p.slug = 'data_export'
   ON CONFLICT (role_id, permission_id) DO NOTHING;
   ```

3. **Напишите down-миграцию** (`000017_seed_my_new_roles.down.sql`):
   ```sql
   -- 1. Remove permission links
   DELETE FROM public.rbac_role_permissions
   WHERE role_id = (SELECT id FROM public.rbac_roles WHERE slug = 'data_exporter');

   -- 2. Delete role
   DELETE FROM public.rbac_roles WHERE slug = 'data_exporter';

   -- 3. Delete permissions
   DELETE FROM public.rbac_permissions WHERE slug = 'data_export';
   ```

4. **Примените миграцию**:
   ```bash
   cd back
   ./src/scripts/xo/migrate-up.sh
   ```

   Для отката:
   ```bash
   ./src/scripts/xo/migrate-down.sh
   ```

5. **Важно**: Всегда используйте `ON CONFLICT (slug) DO NOTHING`, чтобы миграции были идемпотентными (повторный запуск не вызывает ошибок).

Альтернатива — через SQL INSERT напрямую в БД (для быстрого тестирования):

1. Подключитесь к БД: `psql -h localhost -U <user> -d <db>`.
2. Вставьте роль в таблицу `rbac_roles`:
   ```sql
   INSERT INTO rbac_roles (name, slug, created_at, updated_at)
   VALUES ('Data Operator', 'data_operator', NOW(), NOW());
   ```
3. Создайте разрешение в `rbac_permissions`:
   ```sql
   INSERT INTO rbac_permissions (name, slug, created_at, updated_at)
   VALUES ('View Data', 'data_view', NOW(), NOW());
   ```
4. Свяжите разрешение с ролью в `rbac_role_permissions`:
   ```sql
   INSERT INTO rbac_role_permissions (rbac_role_id, rbac_permission_id)
   VALUES (1, 1);
   ```
5. Назначьте роль пользователю в `rbac_user_roles`:
   ```sql
   INSERT INTO rbac_user_roles (rbac_user_id, rbac_role_id, created_at)
   VALUES (42, 1, NOW());
   ```

   Либо используйте RBAC-сервис (Go):
   ```go
   err := rbacSvc.CreateRole("Data Operator", "data_operator")
   err = rbacSvc.CreatePermission("data_view", "data_view")
   err = rbacSvc.AssignPermissionsToRole("data_operator", []string{"data_view"})
   err = rbacSvc.AssignRoleToUser(userID, "data_operator")
   ```

6. Через API:
   - `GET /api/v1/roles` — получить все роли (требует auth).
   - `POST /api/v1/entity/user/:id/roles` с телом `{ "role_slug": "data_operator" }` — назначить роль.
   - `DELETE /api/v1/entity/user/:id/roles/:slug` — отозвать роль.

7. На фронтенде:
   - `fetchAllRoles` (src/lib/role.ts) — GET `/api/v1/roles`.
   - `fetchUserRoles(userId)` — GET `/api/v1/entity/user/:id/roles`.
   - `assignUserRole(userId, roleSlug)` — POST с `{ role_slug }`.
   - `revokeUserRole(userId, roleSlug)` — DELETE.
   - Диалог `RolesDialog` (src/app/(dashboard)/users/roles-dialog.tsx): загружает allRoles + userRoles, отображает чекбоксы. Dirty-set отслеживает изменения. При Save применяются отличия от исходного состояния.

### Create User Avatar

1. **Подготовьте файл**: изображение 460×460 пикселей в формате WebP.

2. **Положите готовый файл в директорию аватаров.** Имя файла: `user-avatar-{id}.webp`, где `{id}` — ID пользователя из БД.

   Директория берётся из конфига (`storage.avatars_dir`). Примеры по окружению:

   | Окружение | Путь |
   |-----------|------|
   | local     | `back/data/local/img/users/avatars/user-avatar-42.webp` |
   | production| `back/data/production/img/users/avatars/user-avatar-42.webp` |
   | e2e       | `back/data/e2e/img/users/avatars/user-avatar-42.webp` |

   ```bash
   # Пример: положить аватар для пользователя с ID=42 (local)
   cp /path/to/460x460.webp back/data/local/img/users/avatars/user-avatar-42.webp
   ```

3. **Без файла** — `GET /api/v1/entity/user/:id/avatar` вернёт дефолтный аватар (встроенный в бинарник через `//go:embed`).

### Delete User

1. **Создайте новую миграцию:**
   ```bash
   cd back
   ./src/scripts/xo/migrate-new.sh ./src/scripts/xo/goxus/migrations
   # Введите имя: soft_delete_john_doe
   ```

2. **Up-миграция** (`000017_soft_delete_john_doe.up.sql`):
   ```sql
   UPDATE public.users
   SET deleted_at = NOW(), updated_at = NOW()
   WHERE email = 'john@example.com' AND deleted_at IS NULL;
   ```

3. **Down-миграция** (`000017_soft_delete_john_doe.down.sql`):
   ```sql
   UPDATE public.users
   SET deleted_at = NULL, updated_at = NOW()
   WHERE email = 'john@example.com' AND deleted_at IS NOT NULL;
   ```

4. **Примените:**
   ```bash
   cd back
   ./src/scripts/xo/migrate-up.sh
   ```

### Change User Roles

1. **Создайте новую миграцию:**
   ```bash
   cd back
   ./src/scripts/xo/migrate-new.sh ./src/scripts/xo/goxus/migrations
   # Введите имя: assign_role_to_user
   ```

2. **Up-миграция** (`000017_assign_role_to_user.up.sql`):
   ```sql
   INSERT INTO public.rbac_user_roles (user_id, role_id)
   SELECT u.id, r.id
   FROM public.users u
            CROSS JOIN public.rbac_roles r
   WHERE u.email = 'john@example.com'
     AND r.slug = 'admin'
   ON CONFLICT (user_id, role_id) DO NOTHING;
   ```

3. **Down-миграция** (`000017_assign_role_to_user.down.sql`):
   ```sql
   DELETE FROM public.rbac_user_roles
   WHERE user_id = (SELECT id FROM public.users WHERE email = 'john@example.com')
     AND role_id = (SELECT id FROM public.rbac_roles WHERE slug = 'admin');
   ```

4. **Примените:**
   ```bash
   cd back
   ./src/scripts/xo/migrate-up.sh
   ```

### Change User Avatar

1. **Замените файл на диске** — просто перезапишите `user-avatar-{id}.webp` новым:

   | Окружение | Команда |
   |-----------|---------|
   | local     | `cp /path/to/new-460x460.webp back/data/local/img/users/avatars/user-avatar-42.webp` |
   | production| `cp /path/to/new-460x460.webp back/data/production/img/users/avatars/user-avatar-42.webp` |

2. **Удалить аватар** (вернуться к дефолтному) — просто удалите файл:
   ```bash
   rm back/data/local/img/users/avatars/user-avatar-42.webp
   ```
   После удаления `GET /api/v1/entity/user/:id/avatar` вернёт встроенный дефолтный аватар.

### Change User Password

1. **Создайте новую миграцию:**
   ```bash
   cd back
   ./src/scripts/xo/migrate-new.sh ./src/scripts/xo/goxus/migrations
   # Введите имя: change_password_john_doe
   ```

2. **Up-миграция** (`000017_change_password_john_doe.up.sql`):
   ```sql
   UPDATE public.users
   SET password = 'new_secret', updated_at = NOW()
   WHERE email = 'john@example.com';
   ```

3. **Down-миграция** (`000017_change_password_john_doe.down.sql`):
   ```sql
   UPDATE public.users
   SET password = 'old_secret', updated_at = NOW()
   WHERE email = 'john@example.com';
   ```

4. **Примените:**
   ```bash
   cd back
   ./src/scripts/xo/migrate-up.sh
   ```
