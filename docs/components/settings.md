# Settings

## Feature List

### Back

- **API определений настроек**

  Возвращает все определения настроек, обогащённые информацией о типе и группе, по `GET /api/v1/entity/settings`. Каждое определение содержит: id, type (строка из `settings_types`), group (строка из `settings_groups`), name, description, available_values (JSON с опциями для полей со списком/выбором) и default_value (JSON с формой значения по умолчанию).

  Реализация: `Service.GetDefinitions()` в `domain/settings/impl.go` — получает все строки из `settings`, резолвит каждый `type_id` → `settings_type.name` и `group_id` → `settings_group.name`, возвращает `[]*SettingsDefinition`.

- **Получение настроек пользователя**

  Возвращает только те настройки, для которых у пользователя есть сохранённое значение, по `GET /api/v1/entity/user/:id/settings`. Каждая настройка обогащена данными определения (type, group, name, description, available_values) плюс значение пользователя. Настройки без сохранённого значения **не возвращаются** — фронтенд использует `default_value` из определений.

  Реализация: `Service.GetUserSettings(userID)` в `domain/settings/impl.go` — проверяет существование пользователя (иначе `ErrUserNotFound`), получает все настройки, фильтрует `users_settings` по `user_id`, обогащает именами типов и групп. Возвращает `[]*UserSetting`.

- **Upsert настройки пользователя (создание или обновление)**

  Создаёт или обновляет значение настройки пользователя по `PUT /api/v1/entity/user/:id/settings/:settings_id`. Тело запроса: `{"value": <внутренние данные>}`. Возвращает `{"message": "setting updated"}` при успехе. Возвращает 404, если пользователь или настройка не найдена.

  Реализация: `Service.UpsertUserSetting(userID, settingsID, value)` — проверяет существование пользователя и настройки; если строка `users_settings` для пары `(userID, settingsID)` существует — обновляет её; иначе вставляет новую. Возвращает `(created bool, error)`, где `created=true` означает новую строку.

- **12 типов настроек, определённых как константы**

  Типы определены в `domain/settings/settings.go` и продублированы в таблице `settings_types` через миграцию `000010`. Каждый тип имеет документированную JSON-форму значения:

  - `inputTextField` — `{"value": "string"}`
  - `inputPasswordField` — `{"value": "string"}`
  - `inputIntNumberField` — `{"value": <int>}`
  - `inputFloatNumberField` — `{"value": <float>}`
  - `textareaField` — `{"value": "string"}`
  - `inputIntSlider` — `{"value": <int>}` + available_values `{"value": {"min": N, "max": N, "step": N}}`
  - `inputIntSliderRange` — `{"value": {"start": N, "end": N}}` + available_values `{"value": {"min": N, "max": N, "step": N}}`
  - `switch` — `{"value": <bool>}`
  - `listChecks` — `{"value": {"key": <bool>, ...}}` + available_values `{"value": {"key": "label", ...}}`
  - `listRadios` — `{"value": <key>}` + available_values `{"value": {"key": "label", ...}}`
  - `selectSimple` — `{"value": <key>}` + available_values `{"value": {"key": "label", ...}}`
  - `selectWithSearch` — `{"value": <key>}` + available_values `{"value": {"key": "label", ...}}`

- **Делегация через DomainService**

  Все операции с настройками доступны через `DomainService` (интерфейс в `domain/domain-app.go`), который делегирует `settingsdomain.Service`:
  - `GetSettingsDefinitions(ctx) → []*SettingsDefinition`
  - `GetUserSettings(ctx, userID) → []*UserSetting`
  - `UpsertUserSetting(ctx, userID, settingsID, value) → error`

  Домен настроек подключён через Google Wire в `domain/settings/provider.go` (`ProviderSet = wire.NewSet(ProvideSettingsService)`).

- **Схема БД (5 миграций)**

  | Миграция | Таблица / Изменение | Назначение |
  |----------|---------------------|------------|
  | 000010 | `settings_types` | 12 типов настроек (inputTextField, switch, listRadios и т.д.) |
  | 000011 | `settings_groups` | Группировка для организации UI (Appearance, Notifications и т.д.) |
  | 000012 | `settings` | Определения настроек — FK к типам и группам, JSON `available_values`, `default_value` |
  | 000013 | `users_settings` | Значения пользователей — FK к users и settings, JSON `value` |
  | 000014 | Уникальный индекс `users_settings_user_id_settings_id_idx` | Гарантирует одно значение на пользователя на настройку, обеспечивает логику upsert |

- **Seed-данные (3 миграции)**

  | Миграция | Содержание |
  |----------|------------|
  | 000012 (внутри) | Theme (listRadios) в группе Appearance — по умолчанию: Light |
  | 000013 (внутри) | Theme = Light для обоих seed-пользователей |
  | 000015 | 4 группы (Notifications, Privacy, Language & Region, Advanced) + 19 настроек |
  | 000016 | 1 группа (Accessibility) + 5 настроек, использующих ранее не задействованные типы |

  **Итого: 6 групп, 26 настроек**, покрывающих все 12 типов.

- **Покрытие тестами ~77%**

  Интеграционные тесты на Testcontainers в `domain/settings/service_test.go` (195 строк):
  - `TestGetDefinitions_Success` — все определения возвращены с резолвом типа/группы
  - `TestGetDefinitions_ThemeSetting` — проверена форма настройки Theme
  - `TestGetUserSettings_Success` — пользователь с seed-настройками получает их
  - `TestGetUserSettings_NotFound` — 99999 возвращает `ErrUserNotFound`
  - `TestGetUserSettings_NoUserSpecificSetting` — чистый список возвращает пустой массив
  - `TestUpsertUserSetting_Create` — новая строка вставляется при первом upsert
  - `TestUpsertUserSetting_Update` — существующая строка обновляется при втором upsert
  - `TestUpsertUserSetting_SettingNotFound` — 99999 возвращает "setting not found"
  - `TestUpsertUserSetting_UserNotFound` — 99999 возвращает "user not found"
  - `TestUpsertUserSetting_VerifyPersistence` — upsert-значение переживает повторное чтение

  Каждый тест получает изолированные seed-данные: `users_settings` очищается перед тестом, создаётся свежая seed-строка, `t.Cleanup` гарантирует очистку.

### Front

- **Страница настроек с боковой навигацией**

  Находится в `src/app/(dashboard)/settings/page.tsx`. Двухколоночная разметка: боковая навигация (вертикальные кнопки на десктопе, `<Select>` выпадающий список на мобильных) + панель содержимого выбранной группы. Использует компонент `<SettingsSidebarNav>` из `src/components/settings-sidebar-nav.tsx`. Первая группа выбирается по умолчанию при загрузке данных. Иконки групп выводятся по имени (Palette для Appearance, Bell для Notifications и т.д., Fallback на Settings2).

- **Динамический реестр компонентов полей**

  Все 12 типов настроек сопоставлены в объекте `fieldRegistry` (`Record<string, React.ComponentType<FieldProps>>`):

  - `inputTextField` → `<InputTextField>` — shadcn `<Input>`, хранит строку
  - `inputPasswordField` → `<InputPasswordField>` — `<Input type="password">`
  - `inputIntNumberField` → `<InputIntNumberField>` — `<Input type="number">`
  - `inputFloatNumberField` → `<InputFloatNumberField>` — `<Input type="number" step="any">`
  - `textareaField` → `<TextareaField>` — `<Textarea>`, 4 строки
  - `inputIntSlider` → `<InputIntSliderField>` — одинарный `<Slider>` + числовая метка; `min`/`max`/`step` из `available_values`
  - `inputIntSliderRange` → `<InputIntSliderRangeField>` — двойной `<Slider>` + метка диапазона; `min`/`max`/`step` из `available_values`
  - `switch` → `<SwitchField>` — `<Switch>` + метка On/Off, хранит bool
  - `listChecks` → `<ListChecksField>` — чекбоксы через `<Checkbox>`, мультивыбор `{"key": bool}`
  - `listRadios` → `<ListRadiosField>` — радио-кнопки через `<RadioGroup>`, одиночный выбор
  - `selectSimple` → `<SelectSimpleField>` — shadcn `<Select>`, одиночный выбор
  - `selectWithSearch` → `<SelectWithSearchField>` — Base UI `<Combobox>` с поиском, одиночный выбор
  - Неизвестные типы → `<UnknownField>` — моноширинный `<Input>` с fallback через JSON.parse

  Каждое поле получает `{ definition, value, onChange }` — `value` это "сырой" JSON от бэкенда в обёртке goxus, `onChange` принимает формат `{"value": <фактическое значение>}`. Пробельные символы в начале и конце строк сохраняются.

- **Цепочка разрешения значений**

  Отображаемое значение для каждой настройки разрешается по приоритету: **dirty-значение > user_setting > default_value**. Настройки пользователя индексированы по `settings_id` для O(1)-доступа. `extractGoxusData()` распаковывает Go-обёртку `{"Data": <внутреннее>}`; `extractSettingValue()` извлекает внутренний ключ `value`; `extractSettingOptions()` парсит `available_values` в `Record<string, string>`.

- **Автосохранение с debounce**

  Нет кнопки сохранения — каждое изменение поля запускает автосохранение через 1-секундный debounce-таймер (`setTimeout` на настройку). При сохранении: вызывает `PUT /api/v1/entity/user/:id/settings/:settings_id` через `upsertUserSetting()`, обновляет локальное состояние `userSettings` (создаёт заглушку при первом сохранении), очищает dirty-маркер и показывает toast об успехе (`sonner.toast`). Неудачные сохранения показывают toast об ошибке. Все таймеры очищаются при размонтировании.

- **API-клиент (`src/lib/settings.ts`)**

  Три функции:
  - `fetchSettingsDefinitions()` — `GET /api/v1/entity/settings` → `SettingsDefinition[]`
  - `fetchUserSettings(userId)` — `GET /api/v1/entity/user/:id/settings` → `UserSetting[]`
  - `upsertUserSetting(userId, settingsId, value)` — `PUT /api/v1/entity/user/:id/settings/:settings_id` с телом `{"value": {"value": <фактическое>}}`

  Все требуют Bearer-токен авторизации; неавторизованные вызовы выбрасывают ошибку.

- **Состояния: загрузка, пусто, ошибка и норма**

  - **Загрузка**: `<Skeleton>`-заглушки (1 заголовок карточки, 1 описание, 3 скелетона полей ввода)
  - **Пусто** (нет определений): сообщение "No settings available."
  - **Ошибка**: "Failed to load settings" с текстом ошибки и кнопкой Retry. Ошибки авторизации (401, "user token not found") перенаправляют на `/login` и очищают токен
  - **Норма**: боковая навигация + содержимое выбранной группы с карточками настроек

- **E2E-тесты (12 тестов)**

  Находятся в `e2e/settings.spec.ts` (477 строк). Тесты:
  - `navigates to settings page from sidebar` — переход по ссылке Settings, проверка URL
  - `renders all setting types with correct components` — проверка всех 6 групп, 26 настроек, 12 типов полей
  - `toggles data retention checkboxes and saves` — взаимодействие с listChecks + toast автосохранения
  - `changes theme and saves` — взаимодействие с listRadios + toast автосохранения
  - `toggles a switch and saves` — переключение switch + toast автосохранения
  - `changes select simple and saves` — selectSimple + toast автосохранения
  - `changes slider and saves` — inputIntSlider (клавиша ArrowRight) + toast автосохранения
  - `changes combobox selection and saves` — selectWithSearch + toast автосохранения
  - `changes integer input and saves` — inputIntNumberField + toast автосохранения
  - `changes float input and saves` — inputFloatNumberField + toast автосохранения
  - `changes text input and saves` — inputTextField + toast автосохранения
  - `changes password input and saves` — inputPasswordField + toast автосохранения

## How to

### Create Settings Type

Новый тип настройки = новый компонент поля на фронтенде + новая константа в Go + новая запись в БД.

**1. Go-константа** — `domain/settings/settings.go`

Добавьте новую константу и JSON-комментарий с форматом value / available_values / default_value:

```go
const (
    // существующие константы...
    SettingsTypeMyNewField = "myNewField"
)

// SettingsTypeMyNewField = "myNewField"
// example saved json value
// {
//    "value": <форма>
// }
// example saved json available_values: null
// (или пример если есть опции)
// example saved json default_value:
// {
//    "value: <форма>
// }
```

**2. Миграция** — создайте новую миграцию

```bash
cd back && ./src/scripts/xo/migrate-new.sh
```

Название: `create_my_setting_type`. В `.up.sql`:

```sql
INSERT INTO public.settings_types (name, description)
VALUES ('myNewField', 'Описание нового типа настройки')
ON CONFLICT (name) DO NOTHING;
```

Примените:

```bash
cd back && ./src/scripts/xo/migrate-up.sh
```

**3. (Опционально) Frontend — компонент поля**

Если новый тип требует уникального рендеринга — добавьте компонент в `src/app/(dashboard)/settings/page.tsx` и зарегистрируйте в `fieldRegistry`:

```tsx
function MyNewField({ definition, value, onChange }: FieldProps) {
  // value — сырой JSON от бэкенда
  // onChange({ value: <фактическое> })
}
```

```tsx
const fieldRegistry: Record<string, React.ComponentType<FieldProps>> = {
  // ...существующие...
  myNewField: MyNewField,
}
```

Типы, которые можно переиспользовать без нового компонента: `UnknownField` (моноширинный инпут + JSON.parse) подойдёт для отладки, но не для продакшена.

**4. Тесты**

Если тип не меняет логику сервиса (GetDefinitions просто вернёт его как строку) — тесты не нужны. Если тип влияет на валидацию в Upsert — добавьте тест-кейс в `service_test.go`.

### Create Settings Group

Группа — чисто организационная сущность. Не требует кода — только миграция и (опционально) кастомная иконка на фронтенде.

**1. Миграция**

```bash
cd back && ./src/scripts/xo/migrate-new.sh
```

Название: `seed_my_group`. В `.up.sql`:

```sql
INSERT INTO public.settings_groups (name, description, order_pos)
VALUES ('My Group', 'Описание группы настроек.', <следующий порядковый номер>)
ON CONFLICT DO NOTHING;
```

Где `order_pos`:
- Appearance = 1
- Notifications = 2
- Privacy = 3
- Language & Region = 4
- Advanced = 5
- Accessibility = 6
- Ваша новая = 7

Примените:

```bash
cd back && ./src/scripts/xo/migrate-up.sh
```

**2. Проверка**

Запустите тест `TestGetDefinitions_Success` в `domain/settings/service_test.go` — он должен подхватить новую группу автоматически (данные data-driven). Если нужно проверить конкретную группу — добавьте тест по аналогии с `TestGetDefinitions_ThemeSetting`.

**3. (Опционально) Frontend — иконка группы**

Иконки автоматически выводятся по имени группы в `groupIcon()` внутри `src/app/(dashboard)/settings/page.tsx`. Если имя не подходит под существующие паттерны — добавьте новый кейс:

```tsx
const groupIcon = useCallback((name: string) => {
    const lower = name.toLowerCase()
    // ...существующие кейсы...
    if (lower.includes("my")) return <IconName size={18} />
    return <Settings2 size={18} />
}, [])
```

Код не требуется — группы подхватываются автоматически из API (`GET /api/v1/entity/settings` → группировка по `def.group`).

### Create Setting

Настройка = новая запись в `settings`, ссылающаяся на существующие `type` и `group`. Кода не требует — только миграция и (опционально) seed user_settings + тест.

**1. Миграция**

```bash
cd back && ./src/scripts/xo/migrate-new.sh
```

Название: `seed_my_setting`. В `.up.sql`:

```sql
INSERT INTO public.settings (type_id, group_id, name, description, available_values, default_value)
SELECT st.id, sg.id, 'My Setting',
       'Описание настройки.',
       '<JSON available_values или {} если нет опций>'::JSON,
       '<JSON default_value>'::JSON
FROM public.settings_types st
         CROSS JOIN public.settings_groups sg
WHERE st.name = '<тип из settings_types>'
  AND sg.name = '<группа из settings_groups>'
ON CONFLICT DO NOTHING;
```

JSON-форматы (значение и опции) должны строго соответствовать типу из `domain/settings/settings.go`. Примеры всех 12 типов — в миграциях `000012`, `000015`, `000016`.

**2. Примените миграцию**

```bash
cd back && ./src/scripts/xo/migrate-up.sh
```

**3. (Опционально) Seed user_settings**

Если нужно, чтобы у определённых пользователей настройка уже была установлена — добавьте `INSERT INTO public.users_settings` в ту же миграцию (по аналогии с `000013`):

```sql
INSERT INTO public.users_settings (user_id, settings_id, value)
SELECT u.id, s.id, '<JSON value>'::JSON
FROM public.users u
         CROSS JOIN public.settings s
         JOIN public.settings_groups sg ON s.group_id = sg.id
         JOIN public.settings_types st ON s.type_id = st.id
WHERE u.email IN ('nobuenhombre@yandex.ru')
  AND st.name = '<тип>'
  AND sg.name = '<группа>'
  AND s.name = 'My Setting'
ON CONFLICT DO NOTHING;
```

**4. Проверка**

Запустите тесты:

```bash
cd back && go test ./... -count=1
```

Новая настройка будет автоматически возвращаться в `GetDefinitions` и `GetUserSettings` — код менять не нужно.

Если у настройки специфическая логика валидации или преобразования — реализуйте её в `UpsertUserSetting` в `impl.go` и добавьте тест в `service_test.go`.

**5. Фронтенд**

Настройка появится автоматически: страница группирует определения по `def.group`, рендерит компонент по `def.type` из `fieldRegistry`. Никаких изменений кода не требуется — только убедитесь, что тип настройки зарегистрирован в `fieldRegistry` (см. `Create Settings Type` шаг 3).
