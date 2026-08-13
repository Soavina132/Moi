-- ═══════════ 0001_extensions.sql ═══════════
-- 0001_extensions.sql
-- Extensions requises

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;

-- ═══════════ 0002_types.sql ═══════════
-- 0002_types.sql
-- Types énumérés, composites et domaines

DO $$ BEGIN CREATE TYPE public.app_role AS ENUM ('admin', 'user'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.game_status AS ENUM ('open', 'playing', 'finished', 'cancelled', 'drawing'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.tx_status AS ENUM ('pending', 'approved', 'rejected'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ═══════════ 0003_sequences.sql ═══════════
-- 0003_sequences.sql
-- Séquences

-- aucune

-- ═══════════ 0004_tables.sql ═══════════
-- 0004_tables.sql
-- Tables du schéma public (sans clés étrangères)

CREATE TABLE IF NOT EXISTS public."achievements" (
  "key" text NOT NULL,
  "label" text NOT NULL,
  "description" text NOT NULL,
  "icon" text DEFAULT '🏅'::text NOT NULL,
  "xp_reward" integer DEFAULT 0 NOT NULL,
  "sort_order" integer DEFAULT 0 NOT NULL,
  CONSTRAINT achievements_pkey PRIMARY KEY (key)
);

CREATE TABLE IF NOT EXISTS public."admin_action_logs" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "admin_id" uuid NOT NULL,
  "action" text NOT NULL,
  "target_type" text,
  "target_id" uuid,
  "payload" jsonb DEFAULT '{}'::jsonb,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT admin_action_logs_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."admin_aliases" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "admin_id" uuid NOT NULL,
  "pseudo" text NOT NULL,
  "avatar_url" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "total_wins" integer DEFAULT 0 NOT NULL,
  "total_games" integer DEFAULT 0 NOT NULL,
  "player_level" integer DEFAULT 1 NOT NULL,
  CONSTRAINT admin_aliases_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."admin_broadcasts" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "message" text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "deleted_at" timestamp with time zone,
  CONSTRAINT admin_broadcasts_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."admin_email_otps" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "code_hash" text NOT NULL,
  "purpose" text DEFAULT 'admin_mfa_backup'::text NOT NULL,
  "attempts" integer DEFAULT 0 NOT NULL,
  "consumed_at" timestamp with time zone,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "expires_at" timestamp with time zone DEFAULT (now() + '00:10:00'::interval) NOT NULL,
  CONSTRAINT admin_email_otps_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."admin_lockouts" (
  "user_id" uuid NOT NULL,
  "locked_until" timestamp with time zone NOT NULL,
  "reason" text,
  "fail_count" integer DEFAULT 0 NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT admin_lockouts_pkey PRIMARY KEY (user_id)
);

CREATE TABLE IF NOT EXISTS public."admin_login_approvals" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "requesting_user_id" uuid NOT NULL,
  "requesting_ip" inet,
  "requesting_user_agent" text,
  "status" text DEFAULT 'pending'::text NOT NULL,
  "approver_user_id" uuid,
  "override_reason" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "decided_at" timestamp with time zone,
  "expires_at" timestamp with time zone DEFAULT (now() + '00:02:00'::interval) NOT NULL,
  CONSTRAINT admin_login_approvals_pkey PRIMARY KEY (id),
  CONSTRAINT admin_login_approvals_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'denied'::text, 'expired'::text, 'override'::text])))
);

CREATE TABLE IF NOT EXISTS public."admin_login_attempts" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid,
  "identifier" text,
  "success" boolean NOT NULL,
  "reason" text,
  "ip" inet,
  "user_agent" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT admin_login_attempts_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."admin_logs" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "admin_id" uuid NOT NULL,
  "target_user_id" uuid,
  "action" text NOT NULL,
  "old_value" jsonb,
  "new_value" jsonb,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT admin_logs_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."admin_persona" (
  "admin_id" uuid NOT NULL,
  "real_pseudo" text DEFAULT ''::text NOT NULL,
  "real_avatar_url" text,
  "persona_pseudo" text,
  "persona_avatar" text,
  "is_active" boolean DEFAULT false NOT NULL,
  "activated_at" timestamp with time zone,
  "alias_id" uuid,
  "real_total_wins" integer DEFAULT 0 NOT NULL,
  "real_total_games" integer DEFAULT 0 NOT NULL,
  "real_player_level" integer DEFAULT 1 NOT NULL,
  CONSTRAINT admin_persona_pkey PRIMARY KEY (admin_id)
);

CREATE TABLE IF NOT EXISTS public."admin_sessions" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "session_fingerprint" text NOT NULL,
  "ip" inet,
  "user_agent" text,
  "mfa_verified" boolean DEFAULT false NOT NULL,
  "approved_by" uuid,
  "override_reason" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "last_seen_at" timestamp with time zone DEFAULT now() NOT NULL,
  "expires_at" timestamp with time zone DEFAULT (now() + '08:00:00'::interval) NOT NULL,
  "revoked_at" timestamp with time zone,
  "revoke_reason" text,
  CONSTRAINT admin_sessions_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."admin_user_messages" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "from_admin" boolean NOT NULL,
  "message" text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "read_at" timestamp with time zone,
  CONSTRAINT admin_user_messages_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."announcements" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "title" text NOT NULL,
  "body" text,
  "image_url" text,
  "link" text,
  "link_label" text,
  "active" boolean DEFAULT true NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT announcements_pkey PRIMARY KEY (id),
  CONSTRAINT announcements_title_check CHECK ((length(TRIM(BOTH FROM title)) > 0))
);

CREATE TABLE IF NOT EXISTS public."app_settings" (
  "id" integer DEFAULT 1 NOT NULL,
  "admin_phone" text DEFAULT '0385708218'::text NOT NULL,
  "admin_label" text DEFAULT 'MVola'::text NOT NULL,
  "signup_bonus" numeric DEFAULT 1 NOT NULL,
  "referral_pct" numeric DEFAULT 5 NOT NULL,
  "game_commission_pct" numeric DEFAULT 10 NOT NULL,
  "min_deposit" numeric DEFAULT 500 NOT NULL,
  "min_withdraw" numeric DEFAULT 1000 NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "paused" boolean DEFAULT false NOT NULL,
  "pause_message" text,
  "download_url" text DEFAULT ''::text,
  "contact_facebook" text DEFAULT ''::text,
  "contact_whatsapp" text DEFAULT ''::text,
  "contact_phone" text DEFAULT ''::text,
  "contact_email" text DEFAULT ''::text,
  "tutorials" jsonb DEFAULT '[]'::jsonb,
  "chat_global_enabled" boolean DEFAULT true,
  "chat_room_enabled" boolean DEFAULT true,
  "live_enabled" boolean DEFAULT true,
  "max_spectators" integer DEFAULT 50,
  "ready_timeout_seconds" integer DEFAULT 60,
  "afk_enabled" boolean DEFAULT true,
  "afk_threshold" integer DEFAULT 2,
  "turn_seconds" integer DEFAULT 30,
  "terms_text" text DEFAULT ''::text,
  "afk_t1_max" integer DEFAULT 2 NOT NULL,
  "afk_t2_max" integer DEFAULT 2 NOT NULL,
  "deposit_help_html" text DEFAULT '<p>Pour déposer, envoyez le montant sur le numéro Mobile Money de l''admin affiché ci-dessus, puis collez la référence de la transaction.</p>'::text,
  "withdrawal_help_html" text DEFAULT '<p>Pour retirer, indiquez votre numéro Mobile Money. Le retrait est traité manuellement par l''admin sous 24h.</p>'::text,
  "games_disabled" jsonb DEFAULT '[]'::jsonb NOT NULL,
  "signup_help_html" text DEFAULT '<p>Pour créer un compte sur Lalao MADA : choisissez un pseudo, entrez votre e-mail et un mot de passe. Validez ensuite votre numéro de téléphone dans votre profil pour pouvoir jouer aux parties payantes.</p>'::text,
  "password_reset_help_html" text DEFAULT '<p>Entrez l''adresse e-mail ou le numéro de téléphone de votre compte. L''admin vous contactera avec un code de réinitialisation par SMS, WhatsApp ou e-mail.</p>'::text,
  "ai_assistant_enabled" boolean DEFAULT true NOT NULL,
  "ai_assistant_context" text,
  "terms_html" text DEFAULT '<p>Lalao MADA est une plateforme de jeux d''adresse en ligne pour la communauté malagasy.</p><ul><li>Vous devez avoir 18 ans ou plus pour jouer avec de l''argent réel.</li><li>Les dépôts et retraits passent par Mobile Money.</li><li>Quitter une partie en cours entraîne la perte automatique de votre mise.</li><li>Les comptes en fraude (multi-comptes, triche) seront bannis.</li></ul>'::text,
  "privacy_html" text DEFAULT '<p>Nous protégeons vos données personnelles.</p><ul><li>Vos informations (e-mail, téléphone, pseudo) ne sont jamais revendues.</li><li>Elles servent uniquement à gérer votre compte, vos parties et vos paiements.</li><li>Vous pouvez demander la suppression de votre compte en contactant l''admin.</li></ul>'::text,
  "chess_global_timer_enabled" boolean DEFAULT false NOT NULL,
  "chess_global_timer_minutes" integer DEFAULT 10 NOT NULL,
  "fanorona_global_timer_enabled" boolean DEFAULT false NOT NULL,
  "fanorona_global_timer_minutes" integer DEFAULT 10 NOT NULL,
  "game_invite_timeout_minutes" integer DEFAULT 6 NOT NULL,
  "daily_bonus_enabled" boolean DEFAULT true NOT NULL,
  "daily_bonus_amount_ar" integer DEFAULT 500 NOT NULL,
  "daily_bonus_streak_bonus" boolean DEFAULT true NOT NULL,
  "referral_enabled" boolean DEFAULT true NOT NULL,
  "mvola_phone" text DEFAULT '0385708218'::text NOT NULL,
  "mvola_name" text DEFAULT 'Jean Pierrit'::text NOT NULL,
  "orange_phone" text DEFAULT '0337145978'::text NOT NULL,
  "orange_name" text DEFAULT 'Jean Pierrit'::text NOT NULL,
  "airtel_phone" text DEFAULT '0372103397'::text NOT NULL,
  "airtel_name" text DEFAULT 'Jean Pierrit'::text NOT NULL,
  "withdrawal_fee_pct" numeric DEFAULT 3 NOT NULL,
  "privacy_text" text DEFAULT ''::text NOT NULL,
  "faq_text" text DEFAULT ''::text NOT NULL,
  "legal_terms" text,
  "legal_privacy" text,
  "poker_turn_seconds" integer DEFAULT 30,
  "poker_rake_pct" numeric DEFAULT 5 NOT NULL,
  "poker_rake_cap" numeric DEFAULT 5000 NOT NULL,
  "poker_min_players_start" integer DEFAULT 2 NOT NULL,
  "poker_starting_stack_ratio" numeric DEFAULT 100 NOT NULL,
  "poker_tournament_late_reg_seconds" integer DEFAULT 300 NOT NULL,
  "solo_bot_enabled" boolean DEFAULT true NOT NULL,
  "ludo_commission_pct" numeric,
  "chess_commission_pct" numeric,
  "domino_commission_pct" numeric,
  "rami_commission_pct" numeric,
  "fanorona_commission_pct" numeric,
  "poker_commission_pct" numeric,
  "billiard_commission_pct" numeric,
  "tournament_commission_pct" numeric,
  "tuto_url" text DEFAULT ''::text NOT NULL,
  "update_url" text DEFAULT ''::text NOT NULL,
  "min_stake" numeric DEFAULT 200 NOT NULL,
  "max_stake" numeric DEFAULT 100000 NOT NULL,
  "tourn_max_concurrent_ludo" integer DEFAULT 5 NOT NULL,
  "tourn_max_concurrent_domino" integer DEFAULT 15 NOT NULL,
  "tourn_max_concurrent_chess" integer DEFAULT 0 NOT NULL,
  "tourn_max_concurrent_petanque" integer DEFAULT 0 NOT NULL,
  CONSTRAINT app_settings_pkey PRIMARY KEY (id),
  CONSTRAINT app_settings_id_check CHECK ((id = 1)),
  CONSTRAINT chk_withdrawal_fee_pct CHECK (((withdrawal_fee_pct >= (0)::numeric) AND (withdrawal_fee_pct <= (100)::numeric)))
);

CREATE TABLE IF NOT EXISTS public."assistant_messages" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "role" text NOT NULL,
  "content" text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT assistant_messages_pkey PRIMARY KEY (id),
  CONSTRAINT assistant_messages_role_check CHECK ((role = ANY (ARRAY['user'::text, 'assistant'::text])))
);

CREATE TABLE IF NOT EXISTS public."balance_audit_log" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "old_balance" numeric NOT NULL,
  "new_balance" numeric NOT NULL,
  "delta" numeric NOT NULL,
  "db_user" text,
  "txid" bigint,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT balance_audit_log_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."billiard_games" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "host_id" uuid NOT NULL,
  "status" text DEFAULT 'open'::text NOT NULL,
  "stake" numeric DEFAULT 0 NOT NULL,
  "pot" numeric DEFAULT 0 NOT NULL,
  "commission_pct" integer DEFAULT 10 NOT NULL,
  "is_private" boolean DEFAULT false NOT NULL,
  "room_code" text,
  "state" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "winner_id" uuid,
  "max_players" integer DEFAULT 2 NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "started_at" timestamp with time zone,
  "finished_at" timestamp with time zone,
  CONSTRAINT billiard_games_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."billiard_participants" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "game_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "slot" integer NOT NULL,
  "ready" boolean DEFAULT false NOT NULL,
  "forfeited" boolean DEFAULT false NOT NULL,
  "score" integer DEFAULT 0 NOT NULL,
  "ball_type" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT billiard_participants_game_id_slot_key UNIQUE (game_id, slot),
  CONSTRAINT billiard_participants_game_id_user_id_key UNIQUE (game_id, user_id),
  CONSTRAINT billiard_participants_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."bug_reports" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "category" text DEFAULT 'general'::text NOT NULL,
  "message" text NOT NULL,
  "status" text DEFAULT 'open'::text NOT NULL,
  "admin_note" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "resolved_at" timestamp with time zone,
  CONSTRAINT bug_reports_pkey PRIMARY KEY (id),
  CONSTRAINT bug_reports_message_check CHECK ((length(TRIM(BOTH FROM message)) >= 5)),
  CONSTRAINT bug_reports_status_check CHECK ((status = ANY (ARRAY['open'::text, 'in_progress'::text, 'resolved'::text, 'closed'::text])))
);

CREATE TABLE IF NOT EXISTS public."chat_members" (
  "room_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "joined_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT chat_members_pkey PRIMARY KEY (room_id, user_id)
);

CREATE TABLE IF NOT EXISTS public."chat_messages" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "room_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "body" text,
  "attachment_url" text,
  "attachment_type" text,
  "reply_to" uuid,
  "pinned" boolean DEFAULT false NOT NULL,
  "edited_at" timestamp with time zone,
  "deleted_at" timestamp with time zone,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "sender_name" text,
  "sender_avatar" text,
  CONSTRAINT chat_messages_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."chat_mutes" (
  "user_id" uuid NOT NULL,
  "until" timestamp with time zone,
  "banned" boolean DEFAULT false NOT NULL,
  "reason" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT chat_mutes_pkey PRIMARY KEY (user_id)
);

CREATE TABLE IF NOT EXISTS public."chat_presence" (
  "user_id" uuid NOT NULL,
  "last_seen" timestamp with time zone DEFAULT now() NOT NULL,
  "current_game" uuid,
  "typing_room" uuid,
  "typing_until" timestamp with time zone,
  CONSTRAINT chat_presence_pkey PRIMARY KEY (user_id)
);

CREATE TABLE IF NOT EXISTS public."chat_reactions" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "message_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "emoji" text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT chat_reactions_message_id_user_id_emoji_key UNIQUE (message_id, user_id, emoji),
  CONSTRAINT chat_reactions_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."chat_rooms" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "type" text NOT NULL,
  "name" text,
  "image_url" text,
  "game_id" uuid,
  "dm_user_a" uuid,
  "dm_user_b" uuid,
  "created_by" uuid,
  "enabled" boolean DEFAULT true NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "joinable" boolean DEFAULT true NOT NULL,
  CONSTRAINT chat_rooms_pkey PRIMARY KEY (id),
  CONSTRAINT chat_rooms_type_check CHECK ((type = ANY (ARRAY['global'::text, 'game'::text, 'dm'::text])))
);

CREATE TABLE IF NOT EXISTS public."chess_games" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "host_id" uuid NOT NULL,
  "white_id" uuid,
  "black_id" uuid,
  "status" game_status DEFAULT 'open'::game_status NOT NULL,
  "stake" numeric NOT NULL,
  "pot" numeric DEFAULT 0 NOT NULL,
  "commission_pct" numeric DEFAULT 10 NOT NULL,
  "turn" text DEFAULT 'w'::text NOT NULL,
  "fen" text DEFAULT 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'::text NOT NULL,
  "ply" integer DEFAULT 0 NOT NULL,
  "winner_id" uuid,
  "draw" boolean DEFAULT false NOT NULL,
  "is_private" boolean DEFAULT false NOT NULL,
  "room_code" text,
  "last_move_at" timestamp with time zone,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "started_at" timestamp with time zone,
  "finished_at" timestamp with time zone,
  "turn_deadline" timestamp with time zone,
  "paused" boolean DEFAULT false NOT NULL,
  "bot_intelligence" integer,
  "bot_name" text,
  "mode" text DEFAULT 'solo'::text NOT NULL,
  "time_control_min" integer DEFAULT 10 NOT NULL,
  "white_time_ms" integer DEFAULT 600000 NOT NULL,
  "black_time_ms" integer DEFAULT 600000 NOT NULL,
  "end_reason" text,
  "draw_offered_by" uuid,
  "resign_offered_by" uuid,
  "white_is_bot" boolean DEFAULT false NOT NULL,
  "black_is_bot" boolean DEFAULT false NOT NULL,
  "game_deadline" timestamp with time zone,
  CONSTRAINT chess_games_room_code_key UNIQUE (room_code),
  CONSTRAINT chess_games_pkey PRIMARY KEY (id),
  CONSTRAINT chess_games_stake_check CHECK ((stake >= (0)::numeric)),
  CONSTRAINT chess_games_turn_check CHECK ((turn = ANY (ARRAY['w'::text, 'b'::text])))
);

CREATE TABLE IF NOT EXISTS public."chess_moves" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "game_id" uuid NOT NULL,
  "ply" integer NOT NULL,
  "san" text NOT NULL,
  "uci" text NOT NULL,
  "fen_after" text NOT NULL,
  "by_user" uuid,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT chess_moves_game_id_ply_key UNIQUE (game_id, ply),
  CONSTRAINT chess_moves_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."cms_content" (
  "key" text NOT NULL,
  "content" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_by" uuid,
  CONSTRAINT cms_content_pkey PRIMARY KEY (key)
);

CREATE TABLE IF NOT EXISTS public."deposits" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "amount" numeric NOT NULL,
  "method" text NOT NULL,
  "reference" text NOT NULL,
  "user_phone" text,
  "status" tx_status DEFAULT 'pending'::tx_status NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "processed_at" timestamp with time zone,
  CONSTRAINT deposits_pkey PRIMARY KEY (id),
  CONSTRAINT deposits_amount_check CHECK ((amount > (0)::numeric))
);

CREATE TABLE IF NOT EXISTS public."domino_games" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "host_id" uuid NOT NULL,
  "max_players" integer NOT NULL,
  "stake" numeric NOT NULL,
  "pot" numeric DEFAULT 0 NOT NULL,
  "commission_pct" numeric DEFAULT 10 NOT NULL,
  "status" game_status DEFAULT 'open'::game_status NOT NULL,
  "is_private" boolean DEFAULT false NOT NULL,
  "room_code" text,
  "mode" text DEFAULT 'classic'::text NOT NULL,
  "state" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "current_turn" integer DEFAULT 0 NOT NULL,
  "winner_id" uuid,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "started_at" timestamp with time zone,
  "finished_at" timestamp with time zone,
  "turn_deadline" timestamp with time zone,
  "target_score" integer DEFAULT 0 NOT NULL,
  "scores" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "turn_skips" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "first_tile_rule" text DEFAULT 'libre'::text NOT NULL,
  "paused" boolean DEFAULT false NOT NULL,
  "pause_deadline" timestamp with time zone,
  "paused_turn_remaining_s" integer,
  "afk_warning" jsonb,
  "afk_pause_for" uuid,
  "afk_pause_name" text,
  "pause_used" boolean DEFAULT false NOT NULL,
  CONSTRAINT domino_games_room_code_key UNIQUE (room_code),
  CONSTRAINT domino_games_pkey PRIMARY KEY (id),
  CONSTRAINT domino_games_max_players_check CHECK (((max_players >= 2) AND (max_players <= 4))),
  CONSTRAINT domino_games_stake_check CHECK ((stake >= (0)::numeric))
);

CREATE TABLE IF NOT EXISTS public."domino_participants" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "game_id" uuid NOT NULL,
  "user_id" uuid,
  "slot" integer NOT NULL,
  "display_name" text NOT NULL,
  "joined_at" timestamp with time zone DEFAULT now() NOT NULL,
  "forfeited" boolean DEFAULT false NOT NULL,
  "ready" boolean DEFAULT false NOT NULL,
  "is_bot" boolean DEFAULT false NOT NULL,
  "bot_name" text,
  "bot_intelligence" integer DEFAULT 70 NOT NULL,
  CONSTRAINT domino_participants_game_id_slot_key UNIQUE (game_id, slot),
  CONSTRAINT domino_participants_game_id_user_id_key UNIQUE (game_id, user_id),
  CONSTRAINT domino_participants_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."fanorona_games" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "host_id" uuid NOT NULL,
  "stake" numeric NOT NULL,
  "pot" numeric DEFAULT 0 NOT NULL,
  "commission_pct" numeric DEFAULT 10 NOT NULL,
  "status" game_status DEFAULT 'open'::game_status NOT NULL,
  "is_private" boolean DEFAULT false NOT NULL,
  "room_code" text,
  "state" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "current_turn" integer DEFAULT 0 NOT NULL,
  "winner_id" uuid,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "started_at" timestamp with time zone,
  "finished_at" timestamp with time zone,
  "turn_deadline" timestamp with time zone,
  "turn_skips" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "draw_white_by" uuid,
  "draw_black_by" uuid,
  "draw_result_color" text,
  "draw_revealed_at" timestamp with time zone,
  "draw_spun_by" uuid,
  "cols" integer DEFAULT 9 NOT NULL,
  "rows" integer DEFAULT 5 NOT NULL,
  "variant" text DEFAULT 'tsivy'::text NOT NULL,
  "mandatory_capture" boolean DEFAULT true NOT NULL,
  "game_deadline" timestamp with time zone,
  "paused" boolean DEFAULT false NOT NULL,
  "pause_deadline" timestamp with time zone,
  "paused_turn_remaining_s" integer,
  "afk_warning" jsonb,
  "afk_pause_for" uuid,
  "afk_pause_name" text,
  "pause_used" boolean DEFAULT false NOT NULL,
  CONSTRAINT fanorona_games_room_code_key UNIQUE (room_code),
  CONSTRAINT fanorona_games_pkey PRIMARY KEY (id),
  CONSTRAINT fanorona_games_stake_check CHECK ((stake >= (0)::numeric))
);

CREATE TABLE IF NOT EXISTS public."fanorona_participants" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "game_id" uuid NOT NULL,
  "user_id" uuid,
  "slot" integer NOT NULL,
  "color" text NOT NULL,
  "display_name" text NOT NULL,
  "joined_at" timestamp with time zone DEFAULT now() NOT NULL,
  "forfeited" boolean DEFAULT false NOT NULL,
  "ready" boolean DEFAULT false NOT NULL,
  "is_bot" boolean DEFAULT false NOT NULL,
  "bot_intelligence" integer DEFAULT 2 NOT NULL,
  "bot_name" text,
  CONSTRAINT fanorona_participants_game_id_slot_key UNIQUE (game_id, slot),
  CONSTRAINT fanorona_participants_game_id_user_id_key UNIQUE (game_id, user_id),
  CONSTRAINT fanorona_participants_pkey PRIMARY KEY (id),
  CONSTRAINT fanorona_participants_color_check CHECK ((color = ANY (ARRAY['white'::text, 'black'::text]))),
  CONSTRAINT fanorona_participants_slot_check CHECK ((slot = ANY (ARRAY[0, 1])))
);

CREATE TABLE IF NOT EXISTS public."friendships" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "requester_id" uuid NOT NULL,
  "addressee_id" uuid NOT NULL,
  "status" text DEFAULT 'pending'::text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT friendships_unique_pair UNIQUE (requester_id, addressee_id),
  CONSTRAINT friendships_pkey PRIMARY KEY (id),
  CONSTRAINT friendships_no_self CHECK ((requester_id <> addressee_id)),
  CONSTRAINT friendships_status_chk CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'blocked'::text])))
);

CREATE TABLE IF NOT EXISTS public."game_configs" (
  "slug" text NOT NULL,
  "display_name" text NOT NULL,
  "turn_timer_seconds" integer DEFAULT 30 NOT NULL,
  "max_turn_skips" integer DEFAULT 5 NOT NULL,
  "rules_markdown" text DEFAULT ''::text NOT NULL,
  "cover_url" text DEFAULT ''::text NOT NULL,
  "max_online_capacity" integer DEFAULT 1000 NOT NULL,
  "instructions_dismissible" boolean DEFAULT true NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "badge" text,
  "tournament_join_timeout_secs" integer DEFAULT 240 NOT NULL,
  CONSTRAINT game_configs_pkey PRIMARY KEY (slug),
  CONSTRAINT game_configs_badge_check CHECK (((badge IS NULL) OR (badge = ANY (ARRAY['new'::text, 'coming_soon'::text, 'hot'::text]))))
);

CREATE TABLE IF NOT EXISTS public."game_invitations" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "sender_id" uuid NOT NULL,
  "receiver_id" uuid NOT NULL,
  "game_slug" text NOT NULL,
  "game_id" uuid,
  "room_code" text,
  "message" text,
  "status" text DEFAULT 'pending'::text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "expires_at" timestamp with time zone DEFAULT (now() + '00:15:00'::interval) NOT NULL,
  CONSTRAINT game_invitations_pkey PRIMARY KEY (id),
  CONSTRAINT gi_no_self CHECK ((sender_id <> receiver_id)),
  CONSTRAINT gi_status_chk CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text, 'expired'::text, 'cancelled'::text])))
);

CREATE TABLE IF NOT EXISTS public."game_spectators" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "game_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "joined_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT game_spectators_game_id_user_id_key UNIQUE (game_id, user_id),
  CONSTRAINT game_spectators_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."house_ledger" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "game_type" text NOT NULL,
  "game_id" uuid,
  "entry_type" text NOT NULL,
  "amount" numeric NOT NULL,
  "pot" numeric,
  "commission_pct" numeric,
  "winner_id" uuid,
  "note" text,
  "meta" jsonb,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT house_ledger_pkey PRIMARY KEY (id),
  CONSTRAINT house_ledger_entry_type_check CHECK ((entry_type = ANY (ARRAY['commission'::text, 'house_win'::text])))
);

CREATE TABLE IF NOT EXISTS public."ludo_games" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "host_id" uuid NOT NULL,
  "max_players" integer NOT NULL,
  "stake" numeric NOT NULL,
  "pot" numeric DEFAULT 0 NOT NULL,
  "commission_pct" numeric DEFAULT 10 NOT NULL,
  "status" game_status DEFAULT 'open'::game_status NOT NULL,
  "state" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "current_turn" integer DEFAULT 0 NOT NULL,
  "winner_id" uuid,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "started_at" timestamp with time zone,
  "finished_at" timestamp with time zone,
  "room_code" text,
  "is_private" boolean DEFAULT false NOT NULL,
  "mode" text DEFAULT 'classic'::text NOT NULL,
  "disconnect_until" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "dice_override" jsonb DEFAULT '{}'::jsonb,
  "spectator_chat_enabled" boolean DEFAULT true,
  "ready_deadline" timestamp with time zone,
  "tournament_match_id" uuid,
  "paused" boolean DEFAULT false NOT NULL,
  "pause_deadline" timestamp with time zone,
  "afk_warning" jsonb,
  "afk_pause_for" uuid,
  "afk_pause_name" text,
  "bot_delay_until" timestamp with time zone,
  "bot_delay_for_stamp" text,
  "is_solo" boolean DEFAULT false NOT NULL,
  "pause_used" boolean DEFAULT false NOT NULL,
  "auto_move" boolean DEFAULT false NOT NULL,
  CONSTRAINT ludo_games_room_code_key UNIQUE (room_code),
  CONSTRAINT ludo_games_pkey PRIMARY KEY (id),
  CONSTRAINT ludo_games_max_players_check CHECK (((max_players >= 2) AND (max_players <= 4))),
  CONSTRAINT ludo_games_stake_check CHECK ((stake >= (0)::numeric))
);

CREATE TABLE IF NOT EXISTS public."ludo_participants" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "game_id" uuid NOT NULL,
  "user_id" uuid,
  "slot" integer NOT NULL,
  "color" text NOT NULL,
  "is_bot" boolean DEFAULT false NOT NULL,
  "bot_name" text,
  "display_name" text NOT NULL,
  "joined_at" timestamp with time zone DEFAULT now() NOT NULL,
  "bot_intelligence" integer DEFAULT 70 NOT NULL,
  "bot_win_bias" integer DEFAULT 0 NOT NULL,
  "forfeited" boolean DEFAULT false NOT NULL,
  "missed_turns" integer DEFAULT 0 NOT NULL,
  "ready" boolean DEFAULT false NOT NULL,
  "last_seen" timestamp with time zone DEFAULT now() NOT NULL,
  "consecutive_sixes" integer DEFAULT 0 NOT NULL,
  "afk_t1" integer DEFAULT 0,
  "afk_t2" integer DEFAULT 0,
  "finish_rank" integer,
  CONSTRAINT ludo_participants_game_id_color_key UNIQUE (game_id, color),
  CONSTRAINT ludo_participants_game_id_slot_key UNIQUE (game_id, slot),
  CONSTRAINT ludo_participants_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."money_offers" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "title" text NOT NULL,
  "description" text,
  "image_url" text,
  "amount_ar" integer,
  "active" boolean DEFAULT true NOT NULL,
  "sort_order" integer DEFAULT 0 NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "link" text,
  "expires_at" timestamp with time zone,
  CONSTRAINT money_offers_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."notifications" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "kind" text DEFAULT 'info'::text NOT NULL,
  "type" text,
  "title" text NOT NULL,
  "body" text,
  "link" text,
  "ref_id" uuid,
  "read" boolean DEFAULT false NOT NULL,
  "read_at" timestamp with time zone,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT notifications_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."password_reset_requests" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "contact" text NOT NULL,
  "contact_type" text NOT NULL,
  "user_id" uuid,
  "code" text,
  "status" text DEFAULT 'pending'::text NOT NULL,
  "admin_note" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "resolved_at" timestamp with time zone,
  CONSTRAINT password_reset_requests_pkey PRIMARY KEY (id),
  CONSTRAINT password_reset_requests_contact_type_check CHECK ((contact_type = ANY (ARRAY['email'::text, 'phone'::text]))),
  CONSTRAINT password_reset_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'sent'::text, 'done'::text, 'rejected'::text])))
);

CREATE TABLE IF NOT EXISTS public."petanque_boules" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "game_id" uuid NOT NULL,
  "round" integer NOT NULL,
  "team" integer NOT NULL,
  "player_id" uuid,
  "play_order" integer NOT NULL,
  "x" double precision NOT NULL,
  "y" double precision NOT NULL,
  "dead" boolean DEFAULT false NOT NULL,
  "distance" double precision DEFAULT 0 NOT NULL,
  "angle" double precision,
  "power" double precision,
  "spin" double precision,
  "lob" double precision,
  "played_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT petanque_boules_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."petanque_games" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "creator_id" uuid,
  "mode" text DEFAULT '1v1'::text NOT NULL,
  "stake" numeric DEFAULT 0 NOT NULL,
  "pot" numeric DEFAULT 0 NOT NULL,
  "status" text DEFAULT 'open'::text NOT NULL,
  "is_private" boolean DEFAULT false NOT NULL,
  "room_code" text,
  "target_points" integer DEFAULT 13 NOT NULL,
  "score_team0" integer DEFAULT 0 NOT NULL,
  "score_team1" integer DEFAULT 0 NOT NULL,
  "current_round" integer DEFAULT 1 NOT NULL,
  "cochonnet_x" double precision DEFAULT 0.55 NOT NULL,
  "cochonnet_y" double precision DEFAULT 0.0 NOT NULL,
  "current_player_id" uuid,
  "turn_deadline" timestamp with time zone,
  "prep_deadline" timestamp with time zone,
  "winner_team" integer,
  "boules_per_player" integer DEFAULT 3 NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "started_at" timestamp with time zone,
  "finished_at" timestamp with time zone,
  "meta" jsonb DEFAULT '{}'::jsonb NOT NULL,
  CONSTRAINT petanque_games_room_code_key UNIQUE (room_code),
  CONSTRAINT petanque_games_pkey PRIMARY KEY (id),
  CONSTRAINT petanque_games_mode_check CHECK ((mode = ANY (ARRAY['1v1'::text, '2v2'::text]))),
  CONSTRAINT petanque_games_status_check CHECK ((status = ANY (ARRAY['open'::text, 'playing'::text, 'finished'::text, 'cancelled'::text])))
);

CREATE TABLE IF NOT EXISTS public."petanque_participants" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "game_id" uuid NOT NULL,
  "user_id" uuid,
  "team" integer NOT NULL,
  "seat" integer NOT NULL,
  "boules_left" integer DEFAULT 3 NOT NULL,
  "ready" boolean DEFAULT false NOT NULL,
  "is_bot" boolean DEFAULT false NOT NULL,
  "joined_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT petanque_participants_game_id_seat_key UNIQUE (game_id, seat),
  CONSTRAINT petanque_participants_pkey PRIMARY KEY (id),
  CONSTRAINT petanque_participants_team_check CHECK ((team = ANY (ARRAY[0, 1])))
);

CREATE TABLE IF NOT EXISTS public."player_achievements" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "achievement_key" text NOT NULL,
  "earned_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT player_achievements_user_id_achievement_key_key UNIQUE (user_id, achievement_key),
  CONSTRAINT player_achievements_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."player_game_stats" (
  "user_id" uuid NOT NULL,
  "game_mode" text NOT NULL,
  "wins" integer DEFAULT 0 NOT NULL,
  "losses" integer DEFAULT 0 NOT NULL,
  "total_winnings" numeric DEFAULT 0 NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "hands_played" integer DEFAULT 0 NOT NULL,
  "hands_won" integer DEFAULT 0 NOT NULL,
  "showdowns_won" integer DEFAULT 0 NOT NULL,
  "biggest_pot" numeric DEFAULT 0 NOT NULL,
  CONSTRAINT player_game_stats_pkey PRIMARY KEY (user_id, game_mode)
);

CREATE TABLE IF NOT EXISTS public."poker_games" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "status" text DEFAULT 'waiting'::text NOT NULL,
  "stake" numeric DEFAULT 0 NOT NULL,
  "commission_pct" numeric DEFAULT 10 NOT NULL,
  "max_players" integer DEFAULT 6 NOT NULL,
  "is_private" boolean DEFAULT false NOT NULL,
  "room_code" text,
  "created_by" uuid,
  "pot" numeric DEFAULT 0 NOT NULL,
  "state" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "phase" text DEFAULT 'waiting'::text NOT NULL,
  "hand_number" integer DEFAULT 0 NOT NULL,
  "community_cards" integer[] DEFAULT '{}'::integer[] NOT NULL,
  "current_player" uuid,
  "turn_deadline" timestamp with time zone,
  "winner_id" uuid,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "started_at" timestamp with time zone,
  "finished_at" timestamp with time zone,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "paused" boolean DEFAULT false NOT NULL,
  "pause_deadline" timestamp with time zone,
  "paused_turn_remaining_s" integer,
  "afk_warning" jsonb,
  "afk_pause_for" uuid,
  "afk_pause_name" text,
  "tournament_id" uuid,
  "table_number" integer,
  "pause_used" boolean DEFAULT false NOT NULL,
  CONSTRAINT poker_games_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."poker_hand_history" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "game_id" uuid NOT NULL,
  "tournament_id" uuid,
  "hand_number" integer NOT NULL,
  "pot" numeric DEFAULT 0 NOT NULL,
  "rake" numeric DEFAULT 0 NOT NULL,
  "board" integer[] DEFAULT '{}'::integer[] NOT NULL,
  "winner_id" uuid,
  "players" jsonb DEFAULT '[]'::jsonb NOT NULL,
  "actions" jsonb DEFAULT '[]'::jsonb NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT poker_hand_history_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."poker_players" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "game_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "seat" integer NOT NULL,
  "chips" numeric DEFAULT 0 NOT NULL,
  "bet_round" numeric DEFAULT 0 NOT NULL,
  "total_bet" numeric DEFAULT 0 NOT NULL,
  "hole_cards" integer[] DEFAULT '{}'::integer[] NOT NULL,
  "status" text DEFAULT 'waiting'::text NOT NULL,
  "is_ready" boolean DEFAULT false NOT NULL,
  "last_action" text,
  "hand_result" jsonb,
  "joined_at" timestamp with time zone DEFAULT now() NOT NULL,
  "is_bot" boolean DEFAULT false NOT NULL,
  "bot_name" text,
  "bot_intelligence" integer,
  "eliminated_at" timestamp with time zone,
  "finish_place" integer,
  CONSTRAINT poker_players_game_id_seat_key UNIQUE (game_id, seat),
  CONSTRAINT poker_players_game_id_user_id_key UNIQUE (game_id, user_id),
  CONSTRAINT poker_players_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."poker_tournament_blind_levels" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "tournament_id" uuid NOT NULL,
  "level" integer NOT NULL,
  "small_blind" numeric NOT NULL,
  "big_blind" numeric NOT NULL,
  "ante" numeric DEFAULT 0 NOT NULL,
  "duration_seconds" integer DEFAULT 600 NOT NULL,
  CONSTRAINT poker_tournament_blind_levels_tournament_id_level_key UNIQUE (tournament_id, level),
  CONSTRAINT poker_tournament_blind_levels_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."poker_tournament_tables" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "tournament_id" uuid NOT NULL,
  "game_id" uuid NOT NULL,
  "table_number" integer NOT NULL,
  "is_final_table" boolean DEFAULT false NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT poker_tournament_tables_game_id_key UNIQUE (game_id),
  CONSTRAINT poker_tournament_tables_tournament_id_table_number_key UNIQUE (tournament_id, table_number),
  CONSTRAINT poker_tournament_tables_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."profiles" (
  "id" uuid NOT NULL,
  "pseudo" text NOT NULL,
  "email" text,
  "balance_ar" numeric DEFAULT 0 NOT NULL,
  "referral_code" text NOT NULL,
  "referred_by" uuid,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "avatar_url" text,
  "unique_code" text,
  "banned" boolean DEFAULT false NOT NULL,
  "status" text DEFAULT 'active'::text NOT NULL,
  "terms_accepted_at" timestamp with time zone,
  "phone" text,
  "phone_verified" boolean DEFAULT false NOT NULL,
  "phone_verification_code" text,
  "phone_verification_requested_at" timestamp with time zone,
  "referral_unlocked" boolean DEFAULT false NOT NULL,
  "phone_verification_code_hash" text,
  "first_deposit_at" timestamp with time zone,
  "first_deposit_amount" numeric,
  "first_game_at" timestamp with time zone,
  "is_banned" boolean DEFAULT false NOT NULL,
  "last_daily_claim" date,
  "daily_streak" integer DEFAULT 0 NOT NULL,
  "total_wins" integer DEFAULT 0 NOT NULL,
  "total_games" integer DEFAULT 0 NOT NULL,
  "player_level" integer DEFAULT 1 NOT NULL,
  "suspended_until" timestamp with time zone,
  "suspension_reason" text,
  "warning_count" integer DEFAULT 0 NOT NULL,
  "phone_number" text,
  "is_premium" boolean DEFAULT false NOT NULL,
  "leaderboard_hidden" boolean DEFAULT false NOT NULL,
  "leaderboard_rank_override" integer,
  "is_bot" boolean DEFAULT false NOT NULL,
  "referral_stake_count" integer DEFAULT 0 NOT NULL,
  "is_admin" boolean DEFAULT false NOT NULL,
  CONSTRAINT profiles_referral_code_key UNIQUE (referral_code),
  CONSTRAINT profiles_unique_code_key UNIQUE (unique_code),
  CONSTRAINT profiles_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."rami_games" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "room_code" text,
  "is_private" boolean DEFAULT true NOT NULL,
  "status" text DEFAULT 'waiting'::text NOT NULL,
  "stake" numeric DEFAULT 0 NOT NULL,
  "pot" numeric DEFAULT 0 NOT NULL,
  "commission_pct" integer DEFAULT 10 NOT NULL,
  "max_players" integer DEFAULT 2 NOT NULL,
  "current_turn" integer DEFAULT 0 NOT NULL,
  "turn_phase" text DEFAULT 'draw'::text NOT NULL,
  "turn_deadline" timestamp with time zone,
  "winner_id" uuid,
  "state" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "created_by" uuid,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "started_at" timestamp with time zone,
  "finished_at" timestamp with time zone,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "turn_skips" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "joker_mode" text DEFAULT 'classique'::text NOT NULL,
  "random_joker" integer,
  "paused" boolean DEFAULT false NOT NULL,
  "pause_deadline" timestamp with time zone,
  "paused_turn_remaining_s" integer,
  "afk_warning" jsonb,
  "afk_pause_for" uuid,
  "afk_pause_name" text,
  "pause_used" boolean DEFAULT false NOT NULL,
  CONSTRAINT rami_games_room_code_key UNIQUE (room_code),
  CONSTRAINT rami_games_pkey PRIMARY KEY (id),
  CONSTRAINT rami_games_joker_mode_chk CHECK ((joker_mode = ANY (ARRAY['sans'::text, 'aleatoire'::text, 'classique'::text, 'double'::text])))
);

CREATE TABLE IF NOT EXISTS public."rami_participants" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "game_id" uuid NOT NULL,
  "user_id" uuid,
  "slot" integer NOT NULL,
  "display_name" text,
  "hand_count" integer DEFAULT 0 NOT NULL,
  "forfeited" boolean DEFAULT false NOT NULL,
  "joined_at" timestamp with time zone DEFAULT now() NOT NULL,
  "ready" boolean DEFAULT false NOT NULL,
  "is_bot" boolean DEFAULT false NOT NULL,
  "bot_name" text,
  "bot_intelligence" integer DEFAULT 70 NOT NULL,
  CONSTRAINT rami_participants_game_id_slot_key UNIQUE (game_id, slot),
  CONSTRAINT rami_participants_game_id_user_id_key UNIQUE (game_id, user_id),
  CONSTRAINT rami_participants_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."referral_events" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "referrer_id" uuid NOT NULL,
  "referee_id" uuid NOT NULL,
  "event_type" text NOT NULL,
  "reward_amount" numeric DEFAULT 0 NOT NULL,
  "note" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT referral_events_referee_id_event_type_key UNIQUE (referee_id, event_type),
  CONSTRAINT referral_events_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."referral_fraud_flags" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "referrer_id" uuid,
  "referee_id" uuid,
  "reason" text NOT NULL,
  "details" jsonb,
  "status" text DEFAULT 'pending'::text NOT NULL,
  "reviewed_by" uuid,
  "reviewed_at" timestamp with time zone,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT referral_fraud_flags_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."referral_settings" (
  "id" integer DEFAULT 1 NOT NULL,
  "enabled" boolean DEFAULT true NOT NULL,
  "deposit_bonus_pct" numeric DEFAULT 10 NOT NULL,
  "deposit_min_ar" numeric DEFAULT 500 NOT NULL,
  "win_commission_pct" numeric DEFAULT 0 NOT NULL,
  "tier_silver_min" integer DEFAULT 5 NOT NULL,
  "tier_gold_min" integer DEFAULT 15 NOT NULL,
  "tier_diamond_min" integer DEFAULT 30 NOT NULL,
  "tier_silver_mult" numeric DEFAULT 1.25 NOT NULL,
  "tier_gold_mult" numeric DEFAULT 1.60 NOT NULL,
  "tier_diamond_mult" numeric DEFAULT 2.00 NOT NULL,
  "require_phone_verification" boolean DEFAULT true NOT NULL,
  "require_first_deposit" boolean DEFAULT true NOT NULL,
  "max_daily_new_referrals" integer DEFAULT 20 NOT NULL,
  "auto_flag_velocity" integer DEFAULT 10 NOT NULL,
  "self_referral_block" boolean DEFAULT true NOT NULL,
  "campaign_label" text,
  "campaign_expires_at" timestamp with time zone,
  "campaign_bonus_pct" numeric,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "stake_commission_pct" numeric DEFAULT 5 NOT NULL,
  "stake_commission_max_matches" integer DEFAULT 10 NOT NULL,
  "unlock_stake_matches" integer DEFAULT 50 NOT NULL,
  CONSTRAINT referral_settings_pkey PRIMARY KEY (id),
  CONSTRAINT referral_settings_stake_max_ck CHECK (((stake_commission_max_matches IS NULL) OR (stake_commission_max_matches >= 0))),
  CONSTRAINT referral_settings_stake_pct_ck CHECK (((stake_commission_pct IS NULL) OR ((stake_commission_pct >= (0)::numeric) AND (stake_commission_pct <= (100)::numeric))))
);

CREATE TABLE IF NOT EXISTS public."support_messages" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "message" text NOT NULL,
  "reply" text,
  "status" text DEFAULT 'open'::text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT support_messages_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."tournament_entrants" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "tournament_id" uuid NOT NULL,
  "user_id" uuid,
  "display_name" text NOT NULL,
  "is_bot" boolean DEFAULT false NOT NULL,
  "status" text DEFAULT 'active'::text NOT NULL,
  "eliminated_round" integer,
  "final_rank" integer,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT tournament_entrants_pkey PRIMARY KEY (id),
  CONSTRAINT tournament_entrants_status_check CHECK ((status = ANY (ARRAY['active'::text, 'eliminated'::text, 'withdrawn'::text])))
);

CREATE TABLE IF NOT EXISTS public."tournament_matches" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "tournament_id" uuid NOT NULL,
  "pool_id" uuid,
  "phase" text DEFAULT 'final'::text NOT NULL,
  "round" integer DEFAULT 1 NOT NULL,
  "match_no" integer DEFAULT 1 NOT NULL,
  "entrant_ids" uuid[] NOT NULL,
  "game_id" uuid,
  "status" text DEFAULT 'scheduled'::text NOT NULL,
  "winner_entrant_id" uuid,
  "started_at" timestamp with time zone,
  "deadline_at" timestamp with time zone,
  "finished_at" timestamp with time zone,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT tournament_matches_pkey PRIMARY KEY (id),
  CONSTRAINT tournament_matches_phase_check CHECK ((phase = ANY (ARRAY['pool'::text, 'final'::text, 'third_place'::text]))),
  CONSTRAINT tournament_matches_status_check CHECK ((status = ANY (ARRAY['scheduled'::text, 'running'::text, 'finished'::text, 'cancelled'::text])))
);

CREATE TABLE IF NOT EXISTS public."tournament_pool_entrants" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "pool_id" uuid NOT NULL,
  "entrant_id" uuid NOT NULL,
  "played" integer DEFAULT 0 NOT NULL,
  "wins" integer DEFAULT 0 NOT NULL,
  "points" integer DEFAULT 0 NOT NULL,
  "qualified" boolean DEFAULT false NOT NULL,
  CONSTRAINT tournament_pool_entrants_pool_id_entrant_id_key UNIQUE (pool_id, entrant_id),
  CONSTRAINT tournament_pool_entrants_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."tournament_pools" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "tournament_id" uuid NOT NULL,
  "label" text NOT NULL,
  "status" text DEFAULT 'pending'::text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT tournament_pools_pkey PRIMARY KEY (id),
  CONSTRAINT tournament_pools_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'running'::text, 'finished'::text])))
);

CREATE TABLE IF NOT EXISTS public."tournaments" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "name" text NOT NULL,
  "description" text,
  "game_slug" text DEFAULT 'ludo'::text NOT NULL,
  "format" text DEFAULT 'knockout'::text NOT NULL,
  "players_per_match" integer DEFAULT 2 NOT NULL,
  "pool_size" integer DEFAULT 4 NOT NULL,
  "qualifiers_per_pool" integer DEFAULT 2 NOT NULL,
  "max_players" integer DEFAULT 32 NOT NULL,
  "entry_fee_ar" numeric DEFAULT 0 NOT NULL,
  "prize_pool_ar" numeric DEFAULT 0 NOT NULL,
  "admin_prize_pool_ar" numeric DEFAULT 0 NOT NULL,
  "platform_pct" numeric DEFAULT 10 NOT NULL,
  "winners_count" integer DEFAULT 1 NOT NULL,
  "prize_1_pct" numeric DEFAULT 100 NOT NULL,
  "prize_2_pct" numeric DEFAULT 0 NOT NULL,
  "prize_3_pct" numeric DEFAULT 0 NOT NULL,
  "max_concurrent_matches" integer DEFAULT 8 NOT NULL,
  "lobby_minutes" integer DEFAULT 5 NOT NULL,
  "auto_advance" boolean DEFAULT true NOT NULL,
  "status" text DEFAULT 'draft'::text NOT NULL,
  "stage" text DEFAULT 'registration'::text NOT NULL,
  "current_round" integer DEFAULT 0 NOT NULL,
  "registration_closes_at" timestamp with time zone,
  "starts_at" timestamp with time zone,
  "started_at" timestamp with time zone,
  "finished_at" timestamp with time zone,
  "champion_entrant_id" uuid,
  "created_by" uuid DEFAULT auth.uid(),
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "is_simulation" boolean DEFAULT false NOT NULL,
  CONSTRAINT tournaments_pkey PRIMARY KEY (id),
  CONSTRAINT tournaments_admin_prize_pool_ar_check CHECK ((admin_prize_pool_ar >= (0)::numeric)),
  CONSTRAINT tournaments_entry_fee_ar_check CHECK ((entry_fee_ar >= (0)::numeric)),
  CONSTRAINT tournaments_format_check CHECK ((format = ANY (ARRAY['pools'::text, 'knockout'::text]))),
  CONSTRAINT tournaments_game_slug_check CHECK ((game_slug = ANY (ARRAY['ludo'::text, 'domino'::text]))),
  CONSTRAINT tournaments_lobby_minutes_check CHECK (((lobby_minutes >= 1) AND (lobby_minutes <= 60))),
  CONSTRAINT tournaments_max_concurrent_matches_check CHECK (((max_concurrent_matches >= 1) AND (max_concurrent_matches <= 64))),
  CONSTRAINT tournaments_max_players_check CHECK (((max_players >= 2) AND (max_players <= 256))),
  CONSTRAINT tournaments_platform_pct_check CHECK (((platform_pct >= (0)::numeric) AND (platform_pct <= (50)::numeric))),
  CONSTRAINT tournaments_players_per_match_check CHECK (((players_per_match >= 2) AND (players_per_match <= 4))),
  CONSTRAINT tournaments_pool_size_check CHECK (((pool_size >= 2) AND (pool_size <= 6))),
  CONSTRAINT tournaments_prize_pool_ar_check CHECK ((prize_pool_ar >= (0)::numeric)),
  CONSTRAINT tournaments_qualifiers_per_pool_check CHECK (((qualifiers_per_pool >= 1) AND (qualifiers_per_pool <= 3))),
  CONSTRAINT tournaments_stage_check CHECK ((stage = ANY (ARRAY['registration'::text, 'pools'::text, 'finals'::text, 'done'::text]))),
  CONSTRAINT tournaments_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'open'::text, 'running'::text, 'paused'::text, 'finished'::text, 'cancelled'::text]))),
  CONSTRAINT tournaments_winners_count_check CHECK (((winners_count >= 1) AND (winners_count <= 3)))
);

CREATE TABLE IF NOT EXISTS public."transactions" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "type" text NOT NULL,
  "amount" numeric NOT NULL,
  "ref_id" uuid,
  "note" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "meta" jsonb,
  CONSTRAINT transactions_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."user_roles" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "role" app_role NOT NULL,
  CONSTRAINT user_roles_user_id_role_key UNIQUE (user_id, role),
  CONSTRAINT user_roles_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public."withdrawal_debts" (
  "user_id" uuid NOT NULL,
  "amount_ar" numeric DEFAULT 0 NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT withdrawal_debts_pkey PRIMARY KEY (user_id),
  CONSTRAINT withdrawal_debts_amount_ar_check CHECK ((amount_ar >= (0)::numeric))
);

CREATE TABLE IF NOT EXISTS public."withdrawals" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "amount" numeric NOT NULL,
  "method" text NOT NULL,
  "user_phone" text NOT NULL,
  "status" tx_status DEFAULT 'pending'::tx_status NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "processed_at" timestamp with time zone,
  "recipient_name" text,
  CONSTRAINT withdrawals_pkey PRIMARY KEY (id),
  CONSTRAINT withdrawals_amount_check CHECK ((amount > (0)::numeric))
);

-- ═══════════ 0005_foreign_keys.sql ═══════════
-- 0005_foreign_keys.sql
-- Clés étrangères

ALTER TABLE public.admin_action_logs ADD CONSTRAINT admin_action_logs_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.admin_aliases ADD CONSTRAINT admin_aliases_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.admin_email_otps ADD CONSTRAINT admin_email_otps_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.admin_lockouts ADD CONSTRAINT admin_lockouts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.admin_login_approvals ADD CONSTRAINT admin_login_approvals_approver_user_id_fkey FOREIGN KEY (approver_user_id) REFERENCES auth.users(id);
ALTER TABLE public.admin_login_approvals ADD CONSTRAINT admin_login_approvals_requesting_user_id_fkey FOREIGN KEY (requesting_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.admin_login_attempts ADD CONSTRAINT admin_login_attempts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.admin_persona ADD CONSTRAINT admin_persona_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.admin_persona ADD CONSTRAINT admin_persona_alias_id_fkey FOREIGN KEY (alias_id) REFERENCES admin_aliases(id) ON DELETE SET NULL;
ALTER TABLE public.admin_sessions ADD CONSTRAINT admin_sessions_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES auth.users(id);
ALTER TABLE public.admin_sessions ADD CONSTRAINT admin_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.assistant_messages ADD CONSTRAINT assistant_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.billiard_games ADD CONSTRAINT billiard_games_host_id_fkey FOREIGN KEY (host_id) REFERENCES auth.users(id);
ALTER TABLE public.billiard_games ADD CONSTRAINT billiard_games_winner_id_fkey FOREIGN KEY (winner_id) REFERENCES auth.users(id);
ALTER TABLE public.billiard_participants ADD CONSTRAINT billiard_participants_game_id_fkey FOREIGN KEY (game_id) REFERENCES billiard_games(id) ON DELETE CASCADE;
ALTER TABLE public.billiard_participants ADD CONSTRAINT billiard_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);
ALTER TABLE public.bug_reports ADD CONSTRAINT bug_reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.chat_messages ADD CONSTRAINT chat_messages_reply_to_fkey FOREIGN KEY (reply_to) REFERENCES chat_messages(id) ON DELETE SET NULL;
ALTER TABLE public.chat_messages ADD CONSTRAINT chat_messages_room_id_fkey FOREIGN KEY (room_id) REFERENCES chat_rooms(id) ON DELETE CASCADE;
ALTER TABLE public.chat_reactions ADD CONSTRAINT chat_reactions_message_id_fkey FOREIGN KEY (message_id) REFERENCES chat_messages(id) ON DELETE CASCADE;
ALTER TABLE public.chess_games ADD CONSTRAINT chess_games_black_id_fkey FOREIGN KEY (black_id) REFERENCES auth.users(id);
ALTER TABLE public.chess_games ADD CONSTRAINT chess_games_host_id_fkey FOREIGN KEY (host_id) REFERENCES auth.users(id);
ALTER TABLE public.chess_games ADD CONSTRAINT chess_games_white_id_fkey FOREIGN KEY (white_id) REFERENCES auth.users(id);
ALTER TABLE public.chess_games ADD CONSTRAINT chess_games_winner_id_fkey FOREIGN KEY (winner_id) REFERENCES auth.users(id);
ALTER TABLE public.chess_moves ADD CONSTRAINT chess_moves_by_user_fkey FOREIGN KEY (by_user) REFERENCES auth.users(id);
ALTER TABLE public.chess_moves ADD CONSTRAINT chess_moves_game_id_fkey FOREIGN KEY (game_id) REFERENCES chess_games(id) ON DELETE CASCADE;
ALTER TABLE public.cms_content ADD CONSTRAINT cms_content_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.deposits ADD CONSTRAINT deposits_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.domino_games ADD CONSTRAINT domino_games_afk_pause_for_fkey FOREIGN KEY (afk_pause_for) REFERENCES profiles(id);
ALTER TABLE public.domino_games ADD CONSTRAINT domino_games_host_id_fkey FOREIGN KEY (host_id) REFERENCES auth.users(id);
ALTER TABLE public.domino_games ADD CONSTRAINT domino_games_winner_id_fkey FOREIGN KEY (winner_id) REFERENCES auth.users(id);
ALTER TABLE public.domino_participants ADD CONSTRAINT domino_participants_game_id_fkey FOREIGN KEY (game_id) REFERENCES domino_games(id) ON DELETE CASCADE;
ALTER TABLE public.domino_participants ADD CONSTRAINT domino_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);
ALTER TABLE public.fanorona_games ADD CONSTRAINT fanorona_games_afk_pause_for_fkey FOREIGN KEY (afk_pause_for) REFERENCES profiles(id);
ALTER TABLE public.fanorona_games ADD CONSTRAINT fanorona_games_host_id_fkey FOREIGN KEY (host_id) REFERENCES auth.users(id);
ALTER TABLE public.fanorona_games ADD CONSTRAINT fanorona_games_winner_id_fkey FOREIGN KEY (winner_id) REFERENCES auth.users(id);
ALTER TABLE public.fanorona_participants ADD CONSTRAINT fanorona_participants_game_id_fkey FOREIGN KEY (game_id) REFERENCES fanorona_games(id) ON DELETE CASCADE;
ALTER TABLE public.fanorona_participants ADD CONSTRAINT fanorona_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);
ALTER TABLE public.friendships ADD CONSTRAINT friendships_addressee_id_fkey FOREIGN KEY (addressee_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.friendships ADD CONSTRAINT friendships_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.game_invitations ADD CONSTRAINT game_invitations_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.game_invitations ADD CONSTRAINT game_invitations_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.ludo_games ADD CONSTRAINT ludo_games_afk_pause_for_fkey FOREIGN KEY (afk_pause_for) REFERENCES profiles(id);
ALTER TABLE public.ludo_games ADD CONSTRAINT ludo_games_host_id_fkey FOREIGN KEY (host_id) REFERENCES auth.users(id);
ALTER TABLE public.ludo_games ADD CONSTRAINT ludo_games_winner_id_fkey FOREIGN KEY (winner_id) REFERENCES auth.users(id);
ALTER TABLE public.ludo_participants ADD CONSTRAINT ludo_participants_game_id_fkey FOREIGN KEY (game_id) REFERENCES ludo_games(id) ON DELETE CASCADE;
ALTER TABLE public.ludo_participants ADD CONSTRAINT ludo_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);
ALTER TABLE public.notifications ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.password_reset_requests ADD CONSTRAINT password_reset_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.petanque_boules ADD CONSTRAINT petanque_boules_game_id_fkey FOREIGN KEY (game_id) REFERENCES petanque_games(id) ON DELETE CASCADE;
ALTER TABLE public.petanque_games ADD CONSTRAINT petanque_games_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.petanque_games ADD CONSTRAINT petanque_games_current_player_id_fkey FOREIGN KEY (current_player_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.petanque_participants ADD CONSTRAINT petanque_participants_game_id_fkey FOREIGN KEY (game_id) REFERENCES petanque_games(id) ON DELETE CASCADE;
ALTER TABLE public.petanque_participants ADD CONSTRAINT petanque_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.player_achievements ADD CONSTRAINT player_achievements_achievement_key_fkey FOREIGN KEY (achievement_key) REFERENCES achievements(key) ON DELETE CASCADE;
ALTER TABLE public.player_achievements ADD CONSTRAINT player_achievements_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.player_game_stats ADD CONSTRAINT player_game_stats_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.poker_games ADD CONSTRAINT poker_games_afk_pause_for_fkey FOREIGN KEY (afk_pause_for) REFERENCES profiles(id);
ALTER TABLE public.poker_games ADD CONSTRAINT poker_games_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.poker_hand_history ADD CONSTRAINT poker_hand_history_game_id_fkey FOREIGN KEY (game_id) REFERENCES poker_games(id) ON DELETE CASCADE;
ALTER TABLE public.poker_hand_history ADD CONSTRAINT poker_hand_history_winner_id_fkey FOREIGN KEY (winner_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.poker_players ADD CONSTRAINT poker_players_game_id_fkey FOREIGN KEY (game_id) REFERENCES poker_games(id) ON DELETE CASCADE;
ALTER TABLE public.poker_tournament_tables ADD CONSTRAINT poker_tournament_tables_game_id_fkey FOREIGN KEY (game_id) REFERENCES poker_games(id) ON DELETE CASCADE;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_referred_by_fkey FOREIGN KEY (referred_by) REFERENCES profiles(id);
ALTER TABLE public.rami_games ADD CONSTRAINT rami_games_afk_pause_for_fkey FOREIGN KEY (afk_pause_for) REFERENCES profiles(id);
ALTER TABLE public.rami_games ADD CONSTRAINT rami_games_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
ALTER TABLE public.rami_participants ADD CONSTRAINT rami_participants_game_id_fkey FOREIGN KEY (game_id) REFERENCES rami_games(id) ON DELETE CASCADE;
ALTER TABLE public.rami_participants ADD CONSTRAINT rami_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);
ALTER TABLE public.referral_events ADD CONSTRAINT referral_events_referee_id_fkey FOREIGN KEY (referee_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.referral_events ADD CONSTRAINT referral_events_referrer_id_fkey FOREIGN KEY (referrer_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.referral_fraud_flags ADD CONSTRAINT referral_fraud_flags_referee_id_fkey FOREIGN KEY (referee_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.referral_fraud_flags ADD CONSTRAINT referral_fraud_flags_referrer_id_fkey FOREIGN KEY (referrer_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.referral_fraud_flags ADD CONSTRAINT referral_fraud_flags_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.support_messages ADD CONSTRAINT support_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_entrants ADD CONSTRAINT tournament_entrants_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_entrants ADD CONSTRAINT tournament_entrants_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_matches ADD CONSTRAINT tournament_matches_pool_id_fkey FOREIGN KEY (pool_id) REFERENCES tournament_pools(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_matches ADD CONSTRAINT tournament_matches_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_matches ADD CONSTRAINT tournament_matches_winner_entrant_id_fkey FOREIGN KEY (winner_entrant_id) REFERENCES tournament_entrants(id) ON DELETE SET NULL;
ALTER TABLE public.tournament_pool_entrants ADD CONSTRAINT tournament_pool_entrants_entrant_id_fkey FOREIGN KEY (entrant_id) REFERENCES tournament_entrants(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_pool_entrants ADD CONSTRAINT tournament_pool_entrants_pool_id_fkey FOREIGN KEY (pool_id) REFERENCES tournament_pools(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_pools ADD CONSTRAINT tournament_pools_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE;
ALTER TABLE public.transactions ADD CONSTRAINT transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.user_roles ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.withdrawal_debts ADD CONSTRAINT withdrawal_debts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.withdrawals ADD CONSTRAINT withdrawals_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ═══════════ 0006_indexes.sql ═══════════
-- 0006_indexes.sql
-- Index

CREATE INDEX IF NOT EXISTS idx_action_logs_admin ON public.admin_action_logs USING btree (admin_id);
CREATE INDEX IF NOT EXISTS idx_action_logs_created ON public.admin_action_logs USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_email_otps_user ON public.admin_email_otps USING btree (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_login_approvals_pending ON public.admin_login_approvals USING btree (status, expires_at) WHERE (status = 'pending'::text);
CREATE INDEX IF NOT EXISTS idx_admin_login_attempts_user_time ON public.admin_login_attempts USING btree (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_active ON public.admin_sessions USING btree (expires_at) WHERE (revoked_at IS NULL);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_user ON public.admin_sessions USING btree (user_id) WHERE (revoked_at IS NULL);
CREATE INDEX IF NOT EXISTS assistant_messages_user_created_idx ON public.assistant_messages USING btree (user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_balance_audit_user ON public.balance_audit_log USING btree (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_billiard_games_lobby ON public.billiard_games USING btree (status, is_private, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_room ON public.chat_messages USING btree (room_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_rooms_dm ON public.chat_rooms USING btree (LEAST(dm_user_a, dm_user_b), GREATEST(dm_user_a, dm_user_b)) WHERE (type = 'dm'::text);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_game ON public.chat_rooms USING btree (game_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_type ON public.chat_rooms USING btree (type);
CREATE INDEX IF NOT EXISTS idx_chess_games_lobby ON public.chess_games USING btree (status, is_private, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_domino_games_lobby ON public.domino_games USING btree (status, is_private, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fanorona_games_lobby ON public.fanorona_games USING btree (status, is_private, created_at DESC);
CREATE INDEX IF NOT EXISTS friendships_addressee_idx ON public.friendships USING btree (addressee_id);
CREATE INDEX IF NOT EXISTS friendships_requester_idx ON public.friendships USING btree (requester_id);
CREATE INDEX IF NOT EXISTS friendships_status_idx ON public.friendships USING btree (status);
CREATE INDEX IF NOT EXISTS gi_receiver_pending_idx ON public.game_invitations USING btree (receiver_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS gi_sender_idx ON public.game_invitations USING btree (sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_house_ledger_created ON public.house_ledger USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_house_ledger_game ON public.house_ledger USING btree (game_type, game_id);
CREATE INDEX IF NOT EXISTS idx_ludo_games_lobby ON public.ludo_games USING btree (status, is_private, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ludo_games_tournament_match ON public.ludo_games USING btree (tournament_match_id);
CREATE INDEX IF NOT EXISTS notifications_user_unread ON public.notifications USING btree (user_id, read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_petanque_boules_game_round ON public.petanque_boules USING btree (game_id, round);
CREATE INDEX IF NOT EXISTS idx_petanque_games_lobby ON public.petanque_games USING btree (status, is_private, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_petanque_participants_game ON public.petanque_participants USING btree (game_id);
CREATE INDEX IF NOT EXISTS player_achievements_user_idx ON public.player_achievements USING btree (user_id);
CREATE INDEX IF NOT EXISTS idx_poker_games_lobby ON public.poker_games USING btree (status, is_private, created_at DESC);
CREATE INDEX IF NOT EXISTS poker_games_status ON public.poker_games USING btree (status);
CREATE INDEX IF NOT EXISTS poker_games_tournament ON public.poker_games USING btree (tournament_id);
CREATE INDEX IF NOT EXISTS poker_hh_game ON public.poker_hand_history USING btree (game_id, hand_number);
CREATE INDEX IF NOT EXISTS poker_hh_winner ON public.poker_hand_history USING btree (winner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS poker_players_game ON public.poker_players USING btree (game_id);
CREATE INDEX IF NOT EXISTS idx_profiles_is_bot ON public.profiles USING btree (is_bot);
CREATE UNIQUE INDEX IF NOT EXISTS profiles_phone_verified_uniq ON public.profiles USING btree (phone) WHERE (phone_verified = true);
CREATE INDEX IF NOT EXISTS idx_rami_games_lobby ON public.rami_games USING btree (status, is_private, created_at DESC);
CREATE INDEX IF NOT EXISTS ref_events_referee ON public.referral_events USING btree (referee_id);
CREATE INDEX IF NOT EXISTS ref_events_referrer ON public.referral_events USING btree (referrer_id);
CREATE INDEX IF NOT EXISTS ref_fraud_referrer ON public.referral_fraud_flags USING btree (referrer_id);
CREATE INDEX IF NOT EXISTS ref_fraud_status ON public.referral_fraud_flags USING btree (status);
CREATE INDEX IF NOT EXISTS tournament_entrants_tid ON public.tournament_entrants USING btree (tournament_id);
CREATE UNIQUE INDEX IF NOT EXISTS tournament_entrants_uniq ON public.tournament_entrants USING btree (tournament_id, user_id) WHERE (user_id IS NOT NULL);
CREATE INDEX IF NOT EXISTS tournament_matches_game ON public.tournament_matches USING btree (game_id);
CREATE INDEX IF NOT EXISTS tournament_matches_tid ON public.tournament_matches USING btree (tournament_id, round);
CREATE INDEX IF NOT EXISTS tournament_pools_tid ON public.tournament_pools USING btree (tournament_id);
CREATE UNIQUE INDEX IF NOT EXISTS transactions_refund_unique ON public.transactions USING btree (user_id, ref_id, type) WHERE ((ref_id IS NOT NULL) AND (type = ANY (ARRAY['refund'::text, 'domino_refund'::text, 'ludo_refund'::text, 'chess_refund'::text, 'rami_refund'::text, 'fanorona_refund'::text, 'poker_refund'::text, 'petanque_refund'::text])));

-- ═══════════ 0007_functions_01.sql ═══════════
-- 0007_functions_01.sql
-- Fonctions et procédures (1/12)

CREATE OR REPLACE FUNCTION public._admin_has_active_session(_exclude_user uuid DEFAULT NULL::uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_sessions s
    WHERE s.revoked_at IS NULL
      AND s.expires_at > now()
      AND s.mfa_verified = true
      AND (_exclude_user IS NULL OR s.user_id <> _exclude_user)
  );
$function$
;

CREATE OR REPLACE FUNCTION public._admin_log(_target uuid, _action text, _old jsonb, _new jsonb)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  INSERT INTO public.admin_logs(admin_id,target_user_id,action,old_value,new_value)
  VALUES (auth.uid(), _target, _action, _old, _new);
$function$
;

CREATE OR REPLACE FUNCTION public._admin_notify_others(_action text, _payload jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE _uid uuid; _me uuid := auth.uid();
BEGIN
  FOR _uid IN SELECT user_id FROM public.user_roles WHERE role = 'admin' AND user_id <> COALESCE(_me, '00000000-0000-0000-0000-000000000000'::uuid)
  LOOP
    INSERT INTO public.notifications(user_id, type, title, body, data)
    VALUES (_uid, 'admin_security',
            '🔐 Alerte sécurité admin',
            _action,
            _payload);
  END LOOP;
  INSERT INTO public.admin_logs(admin_id, action, new_value)
  VALUES (_me, _action, _payload);
EXCEPTION WHEN OTHERS THEN NULL;
END $function$
;

CREATE OR REPLACE FUNCTION public._admin_security_housekeeping()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.admin_sessions
     SET revoked_at = now(), revoke_reason = 'expired'
   WHERE revoked_at IS NULL AND expires_at <= now();

  UPDATE public.admin_login_approvals
     SET status = 'expired', decided_at = now()
   WHERE status = 'pending' AND expires_at <= now();

  DELETE FROM public.admin_lockouts WHERE locked_until <= now() - interval '1 day';
  DELETE FROM public.admin_login_attempts WHERE created_at < now() - interval '90 days';
  DELETE FROM public.admin_email_otps WHERE expires_at < now() - interval '1 day';
END $function$
;

CREATE OR REPLACE FUNCTION public._afk_forfeit_player(_slug text, _game_id uuid, _uid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_max_skips INT; v_slot INT;
BEGIN
  CASE _slug
    WHEN 'ludo' THEN
      UPDATE public.ludo_participants SET afk_t1 = 99 WHERE game_id = _game_id AND user_id = _uid;
      UPDATE public.ludo_games SET paused = FALSE, pause_deadline = NULL, afk_pause_for = NULL, afk_pause_name = NULL, afk_warning = NULL, state = jsonb_set(state, '{turn_started_at}', to_jsonb(now()::text), true) WHERE id = _game_id;
      SELECT slot INTO v_slot FROM public.ludo_participants WHERE game_id = _game_id AND user_id = _uid;
      IF FOUND THEN PERFORM public._ludo_check_afk(_game_id, v_slot); END IF;
    ELSE
      SELECT max_turn_skips INTO v_max_skips FROM public.game_configs WHERE slug = _slug;
      v_max_skips := COALESCE(v_max_skips, 5);
      CASE _slug
        WHEN 'chess' THEN UPDATE public.chess_games SET paused = FALSE, pause_deadline = NULL, afk_pause_for = NULL, afk_pause_name = NULL, afk_warning = NULL, turn_skips = COALESCE(turn_skips, '{}'::jsonb) || jsonb_build_object(_uid::text, v_max_skips + 1), turn_deadline = now() - interval '1 second' WHERE id = _game_id;
        WHEN 'fanorona' THEN UPDATE public.fanorona_games SET paused = FALSE, pause_deadline = NULL, afk_pause_for = NULL, afk_pause_name = NULL, afk_warning = NULL, turn_skips = COALESCE(turn_skips, '{}'::jsonb) || jsonb_build_object(_uid::text, v_max_skips + 1), turn_deadline = now() - interval '1 second' WHERE id = _game_id;
        WHEN 'domino' THEN UPDATE public.domino_games SET paused = FALSE, pause_deadline = NULL, afk_pause_for = NULL, afk_pause_name = NULL, afk_warning = NULL, turn_skips = COALESCE(turn_skips, '{}'::jsonb) || jsonb_build_object(_uid::text, v_max_skips + 1), turn_deadline = now() - interval '1 second' WHERE id = _game_id;
        WHEN 'rami' THEN UPDATE public.rami_games SET paused = FALSE, pause_deadline = NULL, afk_pause_for = NULL, afk_pause_name = NULL, afk_warning = NULL, turn_skips = COALESCE(turn_skips, '{}'::jsonb) || jsonb_build_object(_uid::text, v_max_skips + 1), turn_deadline = now() - interval '1 second' WHERE id = _game_id;
        WHEN 'poker' THEN UPDATE public.poker_games SET paused = FALSE, pause_deadline = NULL, afk_pause_for = NULL, afk_pause_name = NULL, afk_warning = NULL, turn_skips = COALESCE(turn_skips, '{}'::jsonb) || jsonb_build_object(_uid::text, v_max_skips + 1), turn_deadline = now() - interval '1 second' WHERE id = _game_id;
      END CASE;
  END CASE;
END $function$
;

CREATE OR REPLACE FUNCTION public._app_settings_validate_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE msg text;
BEGIN
  msg := public._validate_app_settings(NEW);
  IF msg IS NOT NULL THEN
    RAISE EXCEPTION '%', msg USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;$function$
;

CREATE OR REPLACE FUNCTION public._apply_game_commission()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_type text := TG_ARGV[0];
BEGIN
  NEW.commission_pct := public.get_game_commission(v_type);
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._assert_solo_bot_enabled()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT COALESCE(
    (SELECT solo_bot_enabled FROM public.app_settings WHERE id = 1),
    true
  ) THEN
    RAISE EXCEPTION 'Le mode partie gratuite (Solo vs Bot) est actuellement désactivé par l''administrateur.'
      USING ERRCODE = 'P0001';
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._auto_advance_overdue_turns()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE r record;
BEGIN
  FOR r IN SELECT id FROM public.fanorona_games WHERE status='playing' AND paused = FALSE AND turn_deadline IS NOT NULL AND turn_deadline < now()
  LOOP PERFORM public.fanorona_tick(r.id); END LOOP;
  FOR r IN SELECT id FROM public.chess_games WHERE status='playing' AND paused = FALSE AND turn_deadline IS NOT NULL AND turn_deadline < now()
  LOOP PERFORM public.chess_tick(r.id); END LOOP;
  FOR r IN SELECT id FROM public.domino_games WHERE status='playing' AND paused = FALSE AND turn_deadline IS NOT NULL AND turn_deadline < now()
  LOOP PERFORM public.domino_tick(r.id); END LOOP;
  FOR r IN SELECT id FROM public.rami_games WHERE status='playing' AND paused = FALSE AND turn_deadline IS NOT NULL AND turn_deadline < now()
  LOOP PERFORM public.rami_tick(r.id); END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION public._auto_cancel_open_games()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  r record;
  v_min int;
  v_iv interval;
BEGIN
  SELECT COALESCE(game_invite_timeout_minutes, 6) INTO v_min FROM public.app_settings WHERE id = 1;
  IF v_min IS NULL OR v_min <= 0 THEN v_min := 6; END IF;
  v_iv := (v_min || ' minutes')::interval;

  FOR r IN SELECT id, stake FROM public.fanorona_games WHERE status='open' AND created_at < now() - v_iv
  LOOP
    UPDATE public.profiles p SET balance_ar = balance_ar + r.stake
      FROM public.fanorona_participants pp
      WHERE pp.game_id = r.id AND pp.user_id = p.id
        AND pp.user_id IS NOT NULL AND COALESCE(pp.is_bot,false) = false
        AND r.stake > 0;
    INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
      SELECT user_id, 'fanorona_refund', r.stake, r.id, 'Partie expirée (6 min)'
      FROM public.fanorona_participants
      WHERE game_id = r.id AND user_id IS NOT NULL AND COALESCE(is_bot,false) = false
        AND r.stake > 0;
    UPDATE public.fanorona_games SET status='cancelled', finished_at=now() WHERE id=r.id;
  END LOOP;

  FOR r IN SELECT id, stake, host_id FROM public.chess_games WHERE status='open' AND created_at < now() - v_iv
  LOOP
    IF r.host_id IS NOT NULL AND r.stake > 0 THEN
      UPDATE public.profiles SET balance_ar = balance_ar + r.stake WHERE id = r.host_id;
      INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
        VALUES (r.host_id, 'chess_refund', r.stake, r.id, 'Partie expirée (6 min)');
    END IF;
    UPDATE public.chess_games SET status='cancelled', finished_at=now() WHERE id=r.id;
  END LOOP;

  FOR r IN SELECT id, stake FROM public.domino_games WHERE status='open' AND created_at < now() - v_iv
  LOOP
    UPDATE public.profiles p SET balance_ar = balance_ar + r.stake
      FROM public.domino_participants pp
      WHERE pp.game_id = r.id AND pp.user_id = p.id
        AND pp.user_id IS NOT NULL AND COALESCE(pp.is_bot,false) = false
        AND r.stake > 0;
    INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
      SELECT user_id, 'domino_refund', r.stake, r.id, 'Partie expirée (6 min)'
      FROM public.domino_participants
      WHERE game_id = r.id AND user_id IS NOT NULL AND COALESCE(is_bot,false) = false
        AND r.stake > 0;
    UPDATE public.domino_games SET status='cancelled', finished_at=now() WHERE id=r.id;
  END LOOP;

  FOR r IN SELECT id, stake FROM public.rami_games WHERE status IN ('waiting','open') AND created_at < now() - v_iv
  LOOP
    UPDATE public.profiles p SET balance_ar = balance_ar + r.stake
      FROM public.rami_participants pp
      WHERE pp.game_id = r.id AND pp.user_id = p.id
        AND pp.user_id IS NOT NULL AND COALESCE(pp.is_bot,false) = false
        AND r.stake > 0;
    INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
      SELECT user_id, 'rami_refund', r.stake, r.id, 'Partie expirée (6 min)'
      FROM public.rami_participants
      WHERE game_id = r.id AND user_id IS NOT NULL AND COALESCE(is_bot,false) = false
        AND r.stake > 0;
    UPDATE public.rami_games SET status='cancelled', finished_at=now() WHERE id=r.id;
  END LOOP;

  FOR r IN SELECT id, stake FROM public.ludo_games WHERE status='open' AND created_at < now() - v_iv
  LOOP
    UPDATE public.profiles p SET balance_ar = balance_ar + r.stake
      FROM public.ludo_participants pp
      WHERE pp.game_id = r.id AND pp.user_id = p.id
        AND pp.user_id IS NOT NULL AND COALESCE(pp.is_bot,false) = false
        AND r.stake > 0;
    INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
      SELECT user_id, 'ludo_refund', r.stake, r.id, 'Partie expirée (6 min)'
      FROM public.ludo_participants
      WHERE game_id = r.id AND user_id IS NOT NULL AND COALESCE(is_bot,false) = false
        AND r.stake > 0;
    UPDATE public.ludo_games SET status='cancelled', finished_at=now() WHERE id=r.id;
  END LOOP;

  FOR r IN SELECT id, stake FROM public.poker_games WHERE status='open' AND created_at < now() - v_iv
  LOOP
    UPDATE public.profiles p SET balance_ar = balance_ar + r.stake
      FROM public.poker_players pp
      WHERE pp.game_id = r.id AND pp.user_id = p.id
        AND pp.user_id IS NOT NULL AND COALESCE(pp.is_bot,false) = false
        AND r.stake > 0;
    INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
      SELECT user_id, 'poker_refund', r.stake, r.id, 'Partie expirée (6 min)'
      FROM public.poker_players
      WHERE game_id = r.id AND user_id IS NOT NULL AND COALESCE(is_bot,false) = false
        AND r.stake > 0;
    UPDATE public.poker_games SET status='cancelled', finished_at=now() WHERE id=r.id;
  END LOOP;

  FOR r IN SELECT id, stake FROM public.petanque_games WHERE status='open' AND created_at < now() - v_iv
  LOOP
    UPDATE public.profiles p SET balance_ar = balance_ar + r.stake
      FROM public.petanque_participants pp
      WHERE pp.game_id = r.id AND pp.user_id = p.id
        AND pp.user_id IS NOT NULL AND COALESCE(pp.is_bot,false) = false
        AND r.stake > 0;
    INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
      SELECT user_id, 'petanque_refund', r.stake, r.id, 'Partie expirée (6 min)'
      FROM public.petanque_participants
      WHERE game_id = r.id AND user_id IS NOT NULL AND COALESCE(is_bot,false) = false
        AND r.stake > 0;
    UPDATE public.petanque_games SET status='cancelled', finished_at=now() WHERE id=r.id;
  END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION public._auto_resume_paused_games()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- No-op: la fonctionnalité de pause automatique a été désactivée.
  RETURN;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._chat_snapshot_sender()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.sender_name IS NULL OR NEW.sender_avatar IS NULL THEN
    SELECT COALESCE(NEW.sender_name, p.pseudo, 'Joueur'), COALESCE(NEW.sender_avatar, p.avatar_url)
      INTO NEW.sender_name, NEW.sender_avatar
      FROM public.profiles p WHERE p.id = NEW.user_id;
  END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._chess_ephemeral_bot(_pseudo text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid := gen_random_uuid();
BEGIN
  INSERT INTO auth.users (
    id, instance_id, aud, role,
    email, encrypted_password, email_confirmed_at,
    raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token, email_change, email_change_token_new
  ) VALUES (
    v_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'chessbot_' || v_id::text || '@bot.lalaomada.internal',
    NULL,
    now(),
    jsonb_build_object('pseudo', _pseudo, 'is_bot', true),
    now(), now(),
    '', '', '', ''
  );

  UPDATE public.profiles
    SET balance_ar = 0,
        pseudo = _pseudo,
        avatar_url = NULL
    WHERE id = v_id;

  DELETE FROM public.transactions WHERE user_id = v_id;
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public._chess_gen_code()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE v text; BEGIN
  v := upper(substring(md5(random()::text||clock_timestamp()::text) from 1 for 6));
  RETURN v;
END $function$
;

CREATE OR REPLACE FUNCTION public._chess_payout(_game_id uuid, _winner uuid, _draw boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_g chess_games%ROWTYPE; v_net numeric; v_each numeric;
BEGIN
  SELECT * INTO v_g FROM chess_games WHERE id = _game_id;
  IF v_g.status = 'finished' THEN RETURN; END IF;
  v_net := v_g.pot - (v_g.pot * v_g.commission_pct / 100.0);
  IF _draw THEN
    v_each := v_net / 2;
    IF v_g.white_id IS NOT NULL THEN
      UPDATE profiles SET balance_ar = balance_ar + v_each WHERE id = v_g.white_id;
      INSERT INTO transactions(user_id,type,amount,ref_id,note) VALUES (v_g.white_id,'chess_payout',v_each,_game_id,'Chess draw');
    END IF;
    IF v_g.black_id IS NOT NULL THEN
      UPDATE profiles SET balance_ar = balance_ar + v_each WHERE id = v_g.black_id;
      INSERT INTO transactions(user_id,type,amount,ref_id,note) VALUES (v_g.black_id,'chess_payout',v_each,_game_id,'Chess draw');
    END IF;
    UPDATE chess_games SET status='finished', draw=true, finished_at=now() WHERE id=_game_id;
  ELSE
    UPDATE profiles SET balance_ar = balance_ar + v_net WHERE id = _winner;
    INSERT INTO transactions(user_id,type,amount,ref_id,note) VALUES (_winner,'chess_payout',v_net,_game_id,'Chess win');
    UPDATE chess_games SET status='finished', winner_id=_winner, finished_at=now() WHERE id=_game_id;
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public._chess_settle(_id uuid, _winner uuid, _draw boolean, _reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_g chess_games%ROWTYPE;
  v_prize numeric;
  v_commission numeric;
  v_white_bot boolean;
  v_black_bot boolean;
  v_winner_is_bot boolean;
BEGIN
  SELECT * INTO v_g FROM chess_games WHERE id = _id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_g.status IN ('finished','cancelled') THEN RETURN; END IF;

  v_white_bot := coalesce(v_g.white_is_bot,false);
  v_black_bot := coalesce(v_g.black_is_bot,false);

  IF v_g.mode = 'stake' AND v_g.pot > 0 THEN
    IF _draw THEN
      IF v_g.white_id IS NOT NULL AND NOT v_white_bot THEN
        UPDATE profiles SET balance_ar = balance_ar + v_g.stake WHERE id = v_g.white_id;
        INSERT INTO transactions(user_id,type,amount,meta)
          VALUES (v_g.white_id,'chess_refund',v_g.stake,jsonb_build_object('game',_id,'reason','draw'));
      END IF;
      IF v_g.black_id IS NOT NULL AND NOT v_black_bot THEN
        UPDATE profiles SET balance_ar = balance_ar + v_g.stake WHERE id = v_g.black_id;
        INSERT INTO transactions(user_id,type,amount,meta)
          VALUES (v_g.black_id,'chess_refund',v_g.stake,jsonb_build_object('game',_id,'reason','draw'));
      END IF;
    ELSIF _winner IS NOT NULL THEN
      v_winner_is_bot := (_winner = v_g.white_id AND v_white_bot)
                      OR (_winner = v_g.black_id AND v_black_bot);
      v_commission := round(v_g.pot * (coalesce(v_g.commission_pct,10)/100.0));
      v_prize := v_g.pot - v_commission;
      IF NOT v_winner_is_bot THEN
        UPDATE profiles SET balance_ar = balance_ar + v_prize WHERE id = _winner;
        INSERT INTO transactions(user_id,type,amount,meta)
          VALUES (_winner,'chess_win',v_prize,jsonb_build_object('game',_id,'reason',_reason,'commission',v_commission));
      END IF;
      -- If bot wins: real player's stake stays with the house (no credit).
    END IF;
  END IF;

  UPDATE chess_games SET
    status='finished', winner_id=_winner, draw=_draw, end_reason=_reason,
    finished_at=now(), turn_deadline=NULL
  WHERE id = _id;
END $function$
;

CREATE OR REPLACE FUNCTION public._chess_sync_fen_turn(_fen text, _turn text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  parts text[];
BEGIN
  IF _fen IS NULL OR btrim(_fen) = '' OR _turn IS NULL OR _turn NOT IN ('w','b') THEN
    RETURN _fen;
  END IF;

  parts := regexp_split_to_array(_fen, '\s+');
  IF array_length(parts, 1) < 2 THEN
    RETURN _fen;
  END IF;

  parts[2] := _turn;
  RETURN array_to_string(parts, ' ');
END;
$function$
;

CREATE OR REPLACE FUNCTION public._domino_active_humans(_gid uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT count(*)::int FROM public.domino_participants
  WHERE game_id = _gid AND forfeited = false AND is_bot = false
$function$
;

CREATE OR REPLACE FUNCTION public._domino_apply_turn_timer()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  seconds_left integer;
BEGIN
  IF NEW.turn_deadline IS NULL THEN
    NEW.state := COALESCE(NEW.state, '{}'::jsonb) - 'turn_started_at' - 'turn_duration_seconds';
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' OR OLD.turn_deadline IS DISTINCT FROM NEW.turn_deadline THEN
    seconds_left := GREATEST(1, CEIL(EXTRACT(EPOCH FROM (NEW.turn_deadline - now())))::integer);
    NEW.state := jsonb_set(COALESCE(NEW.state, '{}'::jsonb), '{turn_started_at}', to_jsonb(now()::text), true);
    NEW.state := jsonb_set(NEW.state, '{turn_duration_seconds}', to_jsonb(seconds_left), true);
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._domino_arm_bot_think(_game_id uuid, _slot integer, _state jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_isbot boolean;
  v_state jsonb := COALESCE(_state, '{}'::jsonb);
BEGIN
  SELECT is_bot INTO v_isbot
    FROM public.domino_participants
   WHERE game_id = _game_id AND slot = _slot AND forfeited = false;

  IF NOT COALESCE(v_isbot, false) THEN
    RETURN (v_state - 'bot_think_until') - 'bot_locked_slot';
  END IF;

  -- Fenêtre de réflexion max 2s (auparavant 5s).
  v_state := jsonb_set(v_state - 'bot_think_until' - 'bot_locked_slot', '{bot_locked_slot}', to_jsonb(_slot), true);
  v_state := jsonb_set(v_state, '{bot_think_until}', to_jsonb((now() + interval '2 seconds')::text), true);
  RETURN v_state;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._domino_auto_draw(_game_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g record; st jsonb; stock jsonb; hand jsonb; drawn jsonb;
  slot int; guard int := 0; did boolean := false;
BEGIN
  SELECT * INTO g FROM public.domino_games WHERE id = _game_id;
  IF g.id IS NULL OR g.status <> 'playing' THEN RETURN false; END IF;
  st := g.state;
  IF COALESCE(st->>'draw_mode','with') <> 'with' THEN RETURN false; END IF;
  slot := g.current_turn;
  IF public._domino_slot_has_playable(st, slot) THEN RETURN false; END IF;

  stock := COALESCE(st->'stock','[]'::jsonb);
  hand  := COALESCE(st->'hands'->slot::text,'[]'::jsonb);

  WHILE jsonb_array_length(stock) > 0 AND guard < 30 LOOP
    guard := guard + 1;
    drawn := stock -> 0;
    stock := stock - 0;
    hand  := hand || jsonb_build_array(drawn);
    did   := true;
    st := jsonb_set(st, ARRAY['hands', slot::text], hand);
    st := jsonb_set(st, '{stock}', stock);
    EXIT WHEN public._domino_slot_has_playable(st, slot);
  END LOOP;

  IF NOT did THEN RETURN false; END IF;

  UPDATE public.domino_games
     SET state = st,
         turn_deadline = now() + interval '30 seconds'
   WHERE id = _game_id;
  RETURN public._domino_slot_has_playable(st, slot);
END $function$
;

CREATE OR REPLACE FUNCTION public._domino_autoplay_bots(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  g record; st jsonb; v_slot int; hand jsonb; le int; re int;
  draw_mode text; is_first_move boolean; first_dbl int; v_rule text;
  i int; j int; a int; b int; tile jsonb; placed jsonb;
  found boolean; found_i int; new_hand jsonb; new_left int; new_right int;
  next_turn int; winner_slot int; stock jsonb; drawn jsonb;
  _cfg record; v_is_bot boolean; phase text;
BEGIN
  SELECT * INTO g FROM public.domino_games WHERE id = _game_id FOR UPDATE;
  IF g IS NULL OR g.status <> 'playing' THEN RETURN; END IF;
  st := g.state;
  phase := COALESCE(st->>'phase', 'play');
  IF phase NOT IN ('play','playing') THEN RETURN; END IF;
  v_slot := g.current_turn;
  SELECT COALESCE(dp.is_bot, false) INTO v_is_bot
    FROM public.domino_participants dp
   WHERE dp.game_id = _game_id AND dp.slot = v_slot AND dp.forfeited = false;
  IF NOT COALESCE(v_is_bot, false) THEN RETURN; END IF;

  st := st - 'bot_think_until' - 'bot_locked_slot';

  hand := COALESCE(st->'hands'->v_slot::text, '[]'::jsonb);
  le := NULLIF(st->>'left_end', 'null')::int;
  re := NULLIF(st->>'right_end', 'null')::int;
  draw_mode := COALESCE(st->>'draw_mode', 'with');
  v_rule := COALESCE(st->>'first_tile_rule', 'libre');
  is_first_move := jsonb_array_length(COALESCE(st->'board', '[]'::jsonb)) = 0;
  first_dbl := NULLIF(st->>'first_move_double', 'null')::int;
  SELECT * INTO _cfg FROM public._game_cfg('domino');

  found := false; found_i := -1;
  IF jsonb_array_length(hand) > 0 THEN
    FOR i IN 0..jsonb_array_length(hand)-1 LOOP
      a := (hand->i->>0)::int; b := (hand->i->>1)::int;
      IF is_first_move THEN
        IF first_dbl IS NOT NULL THEN
          IF a = first_dbl AND b = first_dbl THEN found := true; found_i := i; EXIT; END IF;
        ELSIF v_rule = 'under6' THEN
          IF (a + b) < 6 THEN found := true; found_i := i; EXIT; END IF;
        ELSE
          found := true; found_i := i; EXIT;
        END IF;
      ELSE
        IF a = le OR b = le OR a = re OR b = re THEN found := true; found_i := i; EXIT; END IF;
      END IF;
    END LOOP;
  END IF;

  IF found THEN
    tile := hand->found_i;
    a := (tile->>0)::int; b := (tile->>1)::int;
    new_hand := '[]'::jsonb;
    FOR j IN 0..jsonb_array_length(hand)-1 LOOP
      IF j <> found_i THEN new_hand := new_hand || jsonb_build_array(hand->j); END IF;
    END LOOP;

    IF is_first_move THEN
      placed := jsonb_build_array(a, b);
      st := jsonb_set(st, '{board}', jsonb_build_array(jsonb_build_object('tile', placed, 'flipped', false)), true);
      new_left := a; new_right := b;
    ELSE
      IF a = re OR b = re THEN
        IF a = re THEN placed := jsonb_build_array(a, b); new_right := b;
        ELSE placed := jsonb_build_array(b, a); new_right := a; END IF;
        new_left := le;
        st := jsonb_set(st, '{board}', COALESCE(st->'board','[]'::jsonb) || jsonb_build_array(jsonb_build_object('tile', placed, 'flipped', false)), true);
      ELSE
        IF a = le THEN placed := jsonb_build_array(b, a); new_left := b;
        ELSE placed := jsonb_build_array(a, b); new_left := a; END IF;
        new_right := re;
        st := jsonb_set(st, '{board}', jsonb_build_array(jsonb_build_object('tile', placed, 'flipped', false)) || COALESCE(st->'board','[]'::jsonb), true);
      END IF;
    END IF;

    st := jsonb_set(st, ARRAY['hands', v_slot::text], new_hand, true);
    st := jsonb_set(st, '{left_end}', to_jsonb(new_left), true);
    st := jsonb_set(st, '{right_end}', to_jsonb(new_right), true);
    st := jsonb_set(st, '{passes}', to_jsonb(0), true);
    st := jsonb_set(st, '{first_move_double}', 'null'::jsonb, true);
    st := jsonb_set(st, '{phase}', '"play"'::jsonb, true);
    st := st - 'last_pass_by';

    IF jsonb_array_length(new_hand) = 0 THEN
      UPDATE public.domino_games SET state = st WHERE id = _game_id;
      PERFORM public._domino_end_round(_game_id, v_slot);
      RETURN;
    END IF;

    next_turn := public._domino_next_playable_slot(_game_id, v_slot, st);
    IF next_turn IS NULL THEN
      winner_slot := public._domino_lowest_pip_slot(_game_id, st);
      UPDATE public.domino_games SET state = st WHERE id = _game_id;
      PERFORM public._domino_end_round(_game_id, winner_slot);
      RETURN;
    END IF;

    UPDATE public.domino_games
       SET state = st, current_turn = next_turn,
           turn_deadline = now() + (_cfg.turn_timer_seconds || ' seconds')::interval
     WHERE id = _game_id;
    RETURN;
  END IF;

  stock := COALESCE(st->'stock', '[]'::jsonb);
  IF draw_mode = 'with' AND jsonb_array_length(stock) > 0 THEN
    drawn := stock -> 0;
    hand := hand || jsonb_build_array(drawn);
    stock := stock - 0;
    st := jsonb_set(st, ARRAY['hands', v_slot::text], hand, true);
    st := jsonb_set(st, '{stock}', stock, true);
    UPDATE public.domino_games
       SET state = st,
           turn_deadline = now() + (_cfg.turn_timer_seconds || ' seconds')::interval
     WHERE id = _game_id;
    RETURN;
  END IF;

  st := jsonb_set(st, '{passes}', to_jsonb(COALESCE((st->>'passes')::int, 0) + 1), true);
  st := jsonb_set(st, '{last_pass_by}', to_jsonb(v_slot), true);
  next_turn := public._domino_next_playable_slot(_game_id, v_slot, st);
  IF next_turn IS NULL THEN
    winner_slot := public._domino_lowest_pip_slot(_game_id, st);
    UPDATE public.domino_games SET state = st WHERE id = _game_id;
    PERFORM public._domino_end_round(_game_id, winner_slot);
    RETURN;
  END IF;

  UPDATE public.domino_games
     SET state = st, current_turn = next_turn,
         turn_deadline = now() + (_cfg.turn_timer_seconds || ' seconds')::interval
   WHERE id = _game_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._domino_bot_pick_move(_state jsonb, _slot integer, _intel integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  hand jsonb := COALESCE(_state -> 'hands' -> _slot::text, '[]'::jsonb);
  board_len int := jsonb_array_length(COALESCE(_state->'board','[]'::jsonb));
  le int := NULLIF(_state->>'left_end','null')::int;
  re int := NULLIF(_state->>'right_end','null')::int;
  first_dbl int := NULLIF(_state->>'first_move_double','null')::int;
  v_rule text := COALESCE(_state->>'first_tile_rule','libre');
  draw_mode text := COALESCE(_state->>'draw_mode','with');
  stock_len int := jsonb_array_length(COALESCE(_state->'stock','[]'::jsonb));
  n_players int := 0;
  playable jsonb := '[]'::jsonb;
  scored jsonb := '[]'::jsonb;
  t jsonb;
  a int;
  b int;
  ml boolean;
  mr boolean;
  i int;
  n int;
  pick_idx int;
  best_score numeric := -1000000000;
  cur_score numeric;
  new_le int;
  new_re int;
  other_end int;
  hand_size int := jsonb_array_length(hand);
  min_opp_hand int := 999;
  opp_slot int;
  opp_hand jsonb;
  suit_count int[] := ARRAY[0,0,0,0,0,0,0];
  follow_le int;
  follow_re int;
  is_double boolean;
  difficulty text;
  quality_gate numeric;
BEGIN
  IF hand_size = 0 THEN
    RETURN jsonb_build_object('action','pass');
  END IF;

  SELECT count(*) INTO n_players
    FROM jsonb_object_keys(COALESCE(_state->'hands', '{}'::jsonb));

  IF _intel < 40 THEN
    difficulty := 'easy';
  ELSIF _intel < 75 THEN
    difficulty := 'medium';
  ELSE
    difficulty := 'hard';
  END IF;

  FOR t IN SELECT * FROM jsonb_array_elements(hand) LOOP
    a := (t->>0)::int;
    b := (t->>1)::int;
    IF a BETWEEN 0 AND 6 THEN suit_count[a+1] := suit_count[a+1] + 1; END IF;
    IF b BETWEEN 0 AND 6 AND b <> a THEN suit_count[b+1] := suit_count[b+1] + 1; END IF;
  END LOOP;

  IF n_players > 0 THEN
    FOR opp_slot IN 0..(n_players - 1) LOOP
      IF opp_slot <> _slot THEN
        opp_hand := _state->'hands'->opp_slot::text;
        IF opp_hand IS NOT NULL AND jsonb_typeof(opp_hand) = 'array' THEN
          min_opp_hand := LEAST(min_opp_hand, jsonb_array_length(opp_hand));
        END IF;
      END IF;
    END LOOP;
  END IF;

  IF board_len = 0 THEN
    IF first_dbl IS NOT NULL THEN
      FOR t IN SELECT * FROM jsonb_array_elements(hand) LOOP
        a := (t->>0)::int;
        b := (t->>1)::int;
        IF a = first_dbl AND b = first_dbl THEN
          RETURN jsonb_build_object('action','play','tile', t, 'side','right');
        END IF;
      END LOOP;
      IF draw_mode = 'with' AND stock_len > 0 THEN
        RETURN jsonb_build_object('action','draw');
      END IF;
      RETURN jsonb_build_object('action','pass');
    END IF;

    FOR t IN SELECT * FROM jsonb_array_elements(hand) LOOP
      a := (t->>0)::int;
      b := (t->>1)::int;
      IF v_rule <> 'under6' OR (a + b) < 6 THEN
        playable := playable || jsonb_build_array(jsonb_build_object('tile', t, 'side', 'right'));
      END IF;
    END LOOP;
  ELSE
    FOR t IN SELECT * FROM jsonb_array_elements(hand) LOOP
      a := (t->>0)::int;
      b := (t->>1)::int;
      ml := (a = le OR b = le);
      mr := (a = re OR b = re);
      IF mr THEN
        playable := playable || jsonb_build_array(jsonb_build_object('tile', t, 'side', 'right'));
      END IF;
      IF ml AND NOT (mr AND le = re) THEN
        playable := playable || jsonb_build_array(jsonb_build_object('tile', t, 'side', 'left'));
      END IF;
    END LOOP;
  END IF;

  n := jsonb_array_length(playable);
  IF n = 0 THEN
    IF draw_mode = 'with' AND stock_len > 0 THEN
      RETURN jsonb_build_object('action','draw');
    END IF;
    RETURN jsonb_build_object('action','pass');
  END IF;

  IF difficulty = 'easy' THEN
    pick_idx := floor(random() * n)::int;
    RETURN jsonb_build_object('action','play','tile', playable->pick_idx->'tile','side', playable->pick_idx->>'side');
  END IF;

  FOR i IN 0..(n - 1) LOOP
    a := (playable->i->'tile'->>0)::int;
    b := (playable->i->'tile'->>1)::int;
    is_double := a = b;

    IF board_len = 0 THEN
      new_le := a;
      new_re := b;
    ELSIF playable->i->>'side' = 'right' THEN
      new_le := le;
      other_end := CASE WHEN a = re THEN b ELSE a END;
      new_re := other_end;
    ELSE
      other_end := CASE WHEN a = le THEN b ELSE a END;
      new_le := other_end;
      new_re := re;
    END IF;

    follow_le := CASE WHEN new_le BETWEEN 0 AND 6 THEN suit_count[new_le + 1] ELSE 0 END;
    follow_re := CASE WHEN new_re BETWEEN 0 AND 6 THEN suit_count[new_re + 1] ELSE 0 END;
    IF a = new_le OR b = new_le THEN follow_le := GREATEST(0, follow_le - 1); END IF;
    IF a = new_re OR b = new_re THEN follow_re := GREATEST(0, follow_re - 1); END IF;

    -- Professional-style priorities:
    -- 1) empty the hand quickly, 2) keep follow-up numbers, 3) dump high pips
    -- when opponents are close, 4) avoid creating a dead end for ourselves.
    cur_score := 0;
    cur_score := cur_score + (a + b) * CASE WHEN min_opp_hand <= 2 OR hand_size <= 4 THEN 7 ELSE 3 END;
    cur_score := cur_score + (follow_le + follow_re) * CASE WHEN hand_size <= 4 THEN 18 ELSE 8 END;
    cur_score := cur_score + CASE WHEN is_double THEN 16 + (a * 2) ELSE 0 END;
    cur_score := cur_score + CASE WHEN new_le = new_re AND (follow_le + follow_re) > 0 THEN 12 ELSE 0 END;

    IF hand_size <= 3 AND (follow_le + follow_re) = 0 AND hand_size > 1 THEN
      cur_score := cur_score - 45;
    END IF;

    IF min_opp_hand <= 2 THEN
      -- Defensive endgame: prefer ends we still control and high-pip dumping.
      cur_score := cur_score + (follow_le + follow_re) * 14 + (a + b) * 4;
    END IF;

    IF hand_size = 1 THEN
      cur_score := cur_score + 100000;
    END IF;

    IF difficulty = 'medium' THEN
      cur_score := cur_score + (random() * 30) - 10;
    END IF;

    scored := scored || jsonb_build_array(jsonb_build_object(
      'idx', i,
      'score', cur_score,
      'tile', playable->i->'tile',
      'side', playable->i->>'side'
    ));

    IF cur_score > best_score THEN
      best_score := cur_score;
      pick_idx := i;
    END IF;
  END LOOP;

  IF difficulty = 'medium' AND n > 1 THEN
    quality_gate := best_score - 20;
    SELECT COALESCE((x->>'idx')::int, pick_idx) INTO pick_idx
      FROM jsonb_array_elements(scored) AS x
      WHERE (x->>'score')::numeric >= quality_gate
      ORDER BY random()
      LIMIT 1;
  END IF;

  IF pick_idx IS NULL OR pick_idx < 0 THEN pick_idx := 0; END IF;
  RETURN jsonb_build_object('action','play','tile', playable->pick_idx->'tile','side', playable->pick_idx->>'side');
END;
$function$
;

CREATE OR REPLACE FUNCTION public._domino_bot_step(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  g record;
  st jsonb;
  v_slot int;
  v_is_bot boolean;
  phase text;
  v_think_until timestamptz;
  v_locked_slot int;
  v_delay_ms int;
BEGIN
  SELECT * INTO g FROM public.domino_games WHERE id = _game_id FOR UPDATE;
  IF g IS NULL OR g.status <> 'playing' THEN RETURN; END IF;

  st := g.state;
  phase := COALESCE(st->>'phase', 'play');
  IF phase NOT IN ('play','playing') THEN RETURN; END IF;

  v_slot := g.current_turn;
  SELECT COALESCE(dp.is_bot, false) INTO v_is_bot
    FROM public.domino_participants dp
   WHERE dp.game_id = _game_id
     AND dp.slot = v_slot
     AND dp.forfeited = false;

  IF NOT COALESCE(v_is_bot, false) THEN RETURN; END IF;

  v_think_until := NULLIF(st->>'bot_think_until','')::timestamptz;
  v_locked_slot := NULLIF(st->>'bot_locked_slot','null')::int;

  IF v_think_until IS NOT NULL AND v_locked_slot = v_slot AND v_think_until > now() THEN
    RETURN;
  END IF;

  IF v_think_until IS NULL OR v_locked_slot IS DISTINCT FROM v_slot THEN
    v_delay_ms := 1500 + (floor(random() * 2000))::int;
    st := jsonb_set(st - 'bot_think_until' - 'bot_locked_slot',
                    '{bot_locked_slot}', to_jsonb(v_slot), true);
    st := jsonb_set(st, '{bot_think_until}',
                    to_jsonb((now() + make_interval(secs => v_delay_ms / 1000.0))::text), true);
    UPDATE public.domino_games SET state = st WHERE id = _game_id;
    RETURN;
  END IF;

  -- Le délai est écoulé : retirer le verrou et laisser le bot jouer.
  st := st - 'bot_think_until' - 'bot_locked_slot';
  UPDATE public.domino_games SET state = st WHERE id = _game_id;
  PERFORM public._domino_autoplay_bots(_game_id);
END;
$function$
;

CREATE OR REPLACE FUNCTION public._domino_deal(_n_players integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  tiles int[][] := ARRAY[]::int[][];
  a int; b int;
  shuffled jsonb;
  arr jsonb := '[]'::jsonb;
  i int;
BEGIN
  FOR a IN 0..6 LOOP
    FOR b IN a..6 LOOP
      arr := arr || jsonb_build_array(jsonb_build_array(a,b));
    END LOOP;
  END LOOP;
  -- shuffle in SQL
  SELECT jsonb_agg(value ORDER BY random()) INTO shuffled FROM jsonb_array_elements(arr);
  RETURN shuffled;
END $function$
;

CREATE OR REPLACE FUNCTION public._domino_end_round(_game_id uuid, _winner_slot integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g record; st jsonb; winner_uid uuid; round_score int := 0;
  hand_pips jsonb := '{}'::jsonb; p record; pips int; p_key text;
  v_scores jsonb; new_total int; winner_key text;
BEGIN
  SELECT * INTO g FROM public.domino_games WHERE id = _game_id FOR UPDATE;
  IF g.status <> 'playing' THEN RETURN; END IF;

  SELECT user_id INTO winner_uid FROM public.domino_participants WHERE game_id = _game_id AND slot = _winner_slot;
  st := g.state;

  FOR p IN SELECT slot, user_id FROM public.domino_participants WHERE game_id = _game_id LOOP
    pips := public._domino_hand_pips(st->'hands'->p.slot::text);
    p_key := COALESCE(p.user_id::text, 'bot:'||p.slot);
    hand_pips := hand_pips || jsonb_build_object(p_key, pips);
    IF p.slot <> _winner_slot THEN round_score := round_score + pips; END IF;
  END LOOP;

  IF COALESCE(g.target_score,0) <= 0 THEN
    PERFORM public._domino_finalize(_game_id, _winner_slot);
    RETURN;
  END IF;

  winner_key := COALESCE(winner_uid::text, 'bot:'||_winner_slot);
  v_scores := COALESCE(g.scores, '{}'::jsonb);
  new_total := COALESCE((v_scores->>winner_key)::int, 0) + round_score;
  v_scores := jsonb_set(v_scores, ARRAY[winner_key], to_jsonb(new_total), true);

  UPDATE public.domino_games SET scores = v_scores WHERE id = _game_id;

  IF new_total >= g.target_score THEN
    st := jsonb_set(st, '{last_round}', jsonb_build_object(
      'winner_uid', winner_uid, 'round_score', round_score, 'hand_pips', hand_pips, 'final', true
    ));
    UPDATE public.domino_games SET state = st WHERE id = _game_id;
    PERFORM public._domino_finalize(_game_id, _winner_slot);
    RETURN;
  END IF;

  st := jsonb_set(st, '{phase}', '"break"'::jsonb);
  st := jsonb_set(st, '{break_until}', to_jsonb((now() + interval '10 seconds')::text));
  st := jsonb_set(st, '{last_round}', jsonb_build_object(
    'winner_uid', winner_uid, 'round_score', round_score, 'hand_pips', hand_pips, 'final', false
  ));
  st := jsonb_set(st, '{scores}', v_scores);
  UPDATE public.domino_games SET state = st, turn_deadline = NULL WHERE id = _game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public._domino_finalize(_game_id uuid, _winner_slot integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g record; winner_uid uuid; payout numeric; p record; n_active integer; refund_each numeric;
  st jsonb;
BEGIN
  SELECT * INTO g FROM public.domino_games WHERE id = _game_id FOR UPDATE;
  IF g.status = 'finished' THEN RETURN; END IF;

  IF _winner_slot IS NULL THEN
    SELECT count(*) INTO n_active FROM public.domino_participants WHERE game_id = _game_id AND forfeited = false;
    IF n_active > 0 AND g.pot > 0 THEN
      refund_each := floor(g.pot / n_active);
      FOR p IN SELECT user_id FROM public.domino_participants WHERE game_id = _game_id AND forfeited = false AND user_id IS NOT NULL LOOP
        UPDATE public.profiles SET balance_ar = balance_ar + refund_each WHERE id = p.user_id;
        INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
          VALUES (p.user_id, 'domino_draw', refund_each, _game_id, 'Domino match nul – remboursement');
      END LOOP;
    END IF;
    st := jsonb_set(COALESCE(g.state,'{}'::jsonb), '{winner_slot}', 'null'::jsonb, true);
    UPDATE public.domino_games
       SET status='finished', winner_id=NULL, finished_at=now(), state=st
     WHERE id=_game_id;
    RETURN;
  END IF;

  SELECT user_id INTO winner_uid FROM public.domino_participants WHERE game_id = _game_id AND slot = _winner_slot;
  payout := g.pot * (100 - g.commission_pct) / 100;
  IF winner_uid IS NOT NULL THEN
    UPDATE public.profiles SET balance_ar = balance_ar + payout WHERE id = winner_uid;
    INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
      VALUES (winner_uid, 'domino_win', payout, _game_id, 'Domino win');
  END IF;
  st := jsonb_set(COALESCE(g.state,'{}'::jsonb), '{winner_slot}', to_jsonb(_winner_slot), true);
  UPDATE public.domino_games
     SET status='finished', winner_id=winner_uid, finished_at=now(), state=st
   WHERE id=_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public._domino_hand_pips(_hand jsonb)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT COALESCE(SUM(((t->>0)::int + (t->>1)::int)), 0)::int
  FROM jsonb_array_elements(COALESCE(_hand,'[]'::jsonb)) t
$function$
;

CREATE OR REPLACE FUNCTION public._domino_init_state()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT '{"phase":"waiting","hands":{},"stock":[],"board":[],"left_end":null,"right_end":null,"passes":0,"scores":{}}'::jsonb
$function$
;

CREATE OR REPLACE FUNCTION public._domino_lock_game(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended(_game_id::text, 424242));
END $function$
;

CREATE OR REPLACE FUNCTION public._domino_lowest_pip_slot(_game_id uuid, _state jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE p record; cur_sum integer; best_sum integer := 2147483647; best_slot integer := NULL; tie_count integer := 0;
BEGIN
  FOR p IN SELECT slot FROM public.domino_participants WHERE game_id=_game_id AND forfeited=false ORDER BY slot LOOP
    cur_sum := public._domino_hand_pips(COALESCE(_state->'hands'->p.slot::text, '[]'::jsonb));
    IF cur_sum < best_sum THEN best_sum := cur_sum; best_slot := p.slot; tie_count := 1;
    ELSIF cur_sum = best_sum THEN tie_count := tie_count + 1; END IF;
  END LOOP;
  IF tie_count > 1 THEN RETURN NULL; END IF;
  RETURN best_slot;
END; $function$
;

CREATE OR REPLACE FUNCTION public._domino_next_playable_slot(_game_id uuid, _from_slot integer, _state jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  slots integer[];
  total integer;
  start_idx integer := 1;
  step integer;
  idx integer;
  candidate integer;
  draw_mode text := COALESCE(_state->>'draw_mode', 'with');
  stock_len integer := jsonb_array_length(COALESCE(_state -> 'stock', '[]'::jsonb));
BEGIN
  SELECT array_agg(slot ORDER BY slot)
    INTO slots
    FROM public.domino_participants
   WHERE game_id = _game_id AND forfeited = false;

  total := COALESCE(array_length(slots, 1), 0);
  IF total = 0 THEN
    RETURN NULL;
  END IF;

  FOR idx IN 1..total LOOP
    IF slots[idx] = _from_slot THEN
      start_idx := idx;
      EXIT;
    END IF;
  END LOOP;

  FOR step IN 1..total LOOP
    idx := ((start_idx - 1 + step) % total) + 1;
    candidate := slots[idx];

    IF public._domino_slot_has_playable(_state, candidate)
       OR (draw_mode = 'with' AND stock_len > 0) THEN
      RETURN candidate;
    END IF;
  END LOOP;

  RETURN NULL;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._domino_next_round(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  g record; n int; tiles jsonb; hands jsonb := '{}'::jsonb;
  stock jsonb; per_hand int := 7; p record; idx int := 0; hand jsonb;
  starter int := 0; best int := -1; cur_best int; t jsonb;
  starter_double int := -1;
  _cfg record;
  v_round int;
  v_rule text;
  v_prev_starter int;
  slots int[];
  i int;
  a int; b int; sum2 int;
BEGIN
  SELECT * INTO g FROM public.domino_games WHERE id = _game_id FOR UPDATE;
  IF g.status <> 'playing' THEN RETURN; END IF;
  SELECT count(*) INTO n FROM public.domino_participants WHERE game_id = _game_id AND forfeited = false;
  IF n < 2 THEN RETURN; END IF;

  tiles := public._domino_deal(n);

  SELECT array_agg(slot ORDER BY slot) INTO slots
    FROM public.domino_participants WHERE game_id=_game_id AND forfeited=false;

  FOR p IN SELECT * FROM public.domino_participants WHERE game_id = _game_id AND forfeited = false ORDER BY slot LOOP
    SELECT jsonb_agg(value) INTO hand FROM jsonb_array_elements(tiles) WITH ORDINALITY t(value, ord)
      WHERE ord > idx*per_hand AND ord <= (idx+1)*per_hand;
    hands := hands || jsonb_build_object(p.slot::text, COALESCE(hand,'[]'::jsonb));
    idx := idx + 1;
  END LOOP;
  SELECT jsonb_agg(value) INTO stock FROM jsonb_array_elements(tiles) WITH ORDINALITY t(value, ord)
    WHERE ord > n*per_hand;
  stock := COALESCE(stock, '[]'::jsonb);

  v_round := COALESCE((g.state->>'round')::int, 1) + 1;
  v_rule := COALESCE(g.state->>'first_tile_rule', g.first_tile_rule, 'libre');
  v_prev_starter := NULLIF(g.state->>'starter_slot','null')::int;

  IF v_prev_starter IS NOT NULL THEN
    starter := slots[1];
    FOR i IN 1..array_length(slots,1) LOOP
      IF slots[i] = v_prev_starter THEN
        starter := slots[ ((i) % array_length(slots,1)) + 1 ];
        EXIT;
      END IF;
    END LOOP;
    starter_double := -1;
  ELSIF v_rule = 'under6' THEN
    best := -1; starter := slots[1]; starter_double := -1;
    FOR p IN SELECT * FROM public.domino_participants WHERE game_id = _game_id AND forfeited = false ORDER BY slot LOOP
      cur_best := -1;
      FOR t IN SELECT * FROM jsonb_array_elements(hands -> p.slot::text) LOOP
        a := (t->>0)::int; b := (t->>1)::int; sum2 := a + b;
        IF a = b AND sum2 < 6 AND sum2 > cur_best THEN cur_best := sum2; END IF;
      END LOOP;
      IF cur_best > best THEN best := cur_best; starter := p.slot; END IF;
    END LOOP;
    IF best < 0 THEN
      FOR p IN SELECT * FROM public.domino_participants WHERE game_id = _game_id AND forfeited = false ORDER BY slot LOOP
        cur_best := -1;
        FOR t IN SELECT * FROM jsonb_array_elements(hands -> p.slot::text) LOOP
          a := (t->>0)::int; b := (t->>1)::int; sum2 := a + b;
          IF sum2 < 6 AND sum2 > cur_best THEN cur_best := sum2; END IF;
        END LOOP;
        IF cur_best > best THEN best := cur_best; starter := p.slot; END IF;
      END LOOP;
    END IF;
  ELSE
    FOR p IN SELECT * FROM public.domino_participants WHERE game_id = _game_id AND forfeited = false ORDER BY slot LOOP
      cur_best := -1;
      FOR t IN SELECT * FROM jsonb_array_elements(hands -> p.slot::text) LOOP
        IF (t->>0)::int = (t->>1)::int AND (t->>0)::int > cur_best THEN cur_best := (t->>0)::int; END IF;
      END LOOP;
      IF cur_best > best THEN best := cur_best; starter := p.slot; starter_double := cur_best; END IF;
    END LOOP;
  END IF;

  SELECT * INTO _cfg FROM public._game_cfg('domino');

  -- Reset "ready" côté participants pour repartir proprement
  UPDATE public.domino_participants
     SET ready = false
   WHERE game_id = _game_id;

  UPDATE public.domino_games SET
    current_turn = starter,
    turn_deadline = now() + (_cfg.turn_timer_seconds || ' seconds')::interval,
    turn_skips = '{}'::jsonb,
    state = jsonb_build_object(
      'phase','playing',
      'hands', hands,
      'stock', stock,
      'board', '[]'::jsonb,
      'left_end', 'null'::jsonb,
      'right_end', 'null'::jsonb,
      'passes', 0,
      'scores', COALESCE(g.scores, g.state->'scores', '{}'::jsonb),
      'round', v_round,
      'last_round', NULL,
      'reveal_until', NULL,
      'break_until', NULL,
      'draw_mode', COALESCE(g.state->>'draw_mode','with'),
      'first_tile_rule', v_rule,
      'starter_slot', to_jsonb(starter),
      'first_move_double', CASE WHEN starter_double >= 0 THEN to_jsonb(starter_double) ELSE 'null'::jsonb END
    )
  WHERE id = _game_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._domino_normalize_board(_board jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  chain jsonb := '[]'::jsonb;
  entry jsonb;
  tile jsonb;
  placed jsonb;
  a int;
  b int;
  le int;
  re int;
  i int := 0;
BEGIN
  IF _board IS NULL OR jsonb_typeof(_board) <> 'array' OR jsonb_array_length(_board) = 0 THEN
    RETURN jsonb_build_object('board', '[]'::jsonb, 'left_end', NULL, 'right_end', NULL);
  END IF;

  FOR entry IN SELECT value FROM jsonb_array_elements(_board) AS value LOOP
    tile := CASE
      WHEN jsonb_typeof(entry) = 'array' THEN entry
      ELSE entry->'tile'
    END;

    IF tile IS NULL OR jsonb_typeof(tile) <> 'array' OR jsonb_array_length(tile) <> 2 THEN
      CONTINUE;
    END IF;

    a := (tile->>0)::int;
    b := (tile->>1)::int;

    IF i = 0 THEN
      chain := jsonb_build_array(jsonb_build_object('tile', jsonb_build_array(a, b), 'flipped', false));
      le := a;
      re := b;
    ELSE
      IF a = re THEN
        placed := jsonb_build_object('tile', jsonb_build_array(a, b), 'flipped', false);
        chain := chain || jsonb_build_array(placed);
        re := b;
      ELSIF b = re THEN
        placed := jsonb_build_object('tile', jsonb_build_array(b, a), 'flipped', false);
        chain := chain || jsonb_build_array(placed);
        re := a;
      ELSIF b = le THEN
        placed := jsonb_build_object('tile', jsonb_build_array(a, b), 'flipped', false);
        chain := jsonb_build_array(placed) || chain;
        le := a;
      ELSIF a = le THEN
        placed := jsonb_build_object('tile', jsonb_build_array(b, a), 'flipped', false);
        chain := jsonb_build_array(placed) || chain;
        le := b;
      ELSE
        -- Keep malformed legacy entries visible without changing endpoints.
        chain := chain || jsonb_build_array(jsonb_build_object('tile', jsonb_build_array(a, b), 'flipped', false));
      END IF;
    END IF;

    i := i + 1;
  END LOOP;

  IF jsonb_array_length(chain) = 0 THEN
    RETURN jsonb_build_object('board', '[]'::jsonb, 'left_end', NULL, 'right_end', NULL);
  END IF;

  RETURN jsonb_build_object('board', chain, 'left_end', le, 'right_end', re);
END;
$function$
;

CREATE OR REPLACE FUNCTION public._domino_place_first(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  g record;
  st jsonb;
  starter int;
  starter_double int;
  hands jsonb;
  starter_hand jsonb;
  filtered jsonb;
  board jsonb;
  next_slot int;
  _cfg record;
BEGIN
  SELECT * INTO g FROM public.domino_games WHERE id = _game_id FOR UPDATE;
  IF g IS NULL OR g.status <> 'playing' THEN RETURN; END IF;

  st := g.state;
  IF COALESCE(st->>'phase', '') NOT IN ('dealing', 'play', 'playing') THEN RETURN; END IF;

  starter := COALESCE(NULLIF(st->>'starter_slot','null')::int, g.current_turn);
  starter_double := COALESCE(NULLIF(st->>'starter_double','null')::int, NULLIF(st->>'first_move_double','null')::int, -1);
  hands := COALESCE(st->'hands', '{}'::jsonb);

  IF jsonb_array_length(COALESCE(st->'board', '[]'::jsonb)) = 0 AND starter_double >= 0 THEN
    starter_hand := COALESCE(hands -> starter::text, '[]'::jsonb);

    SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
      INTO filtered
      FROM jsonb_array_elements(starter_hand) AS e(elem)
     WHERE NOT ((elem->>0)::int = starter_double AND (elem->>1)::int = starter_double);

    hands := jsonb_set(hands, ARRAY[starter::text], filtered, true);
    board := jsonb_build_array(jsonb_build_object('tile', jsonb_build_array(starter_double, starter_double), 'flipped', false));

    st := jsonb_set(st, '{hands}', hands, true);
    st := jsonb_set(st, '{board}', board, true);
    st := jsonb_set(st, '{left_end}', to_jsonb(starter_double), true);
    st := jsonb_set(st, '{right_end}', to_jsonb(starter_double), true);
    st := jsonb_set(st, '{first_move_double}', 'null'::jsonb, true);

    SELECT dp.slot INTO next_slot
      FROM public.domino_participants dp
     WHERE dp.game_id = _game_id AND dp.forfeited = false AND dp.slot > starter
     ORDER BY dp.slot
     LIMIT 1;

    IF next_slot IS NULL THEN
      SELECT dp.slot INTO next_slot
        FROM public.domino_participants dp
       WHERE dp.game_id = _game_id AND dp.forfeited = false
       ORDER BY dp.slot
       LIMIT 1;
    END IF;
  ELSE
    next_slot := starter;
    st := jsonb_set(st, '{first_move_double}', 'null'::jsonb, true);
  END IF;

  st := jsonb_set(st, '{phase}', '"play"'::jsonb, true) - 'deal_until';
  SELECT * INTO _cfg FROM public._game_cfg('domino');

  UPDATE public.domino_games
     SET state = st,
         current_turn = COALESCE(next_slot, starter),
         turn_deadline = now() + (_cfg.turn_timer_seconds || ' seconds')::interval
   WHERE id = _game_id;

  PERFORM public._domino_bot_step(_game_id);
END;
$function$
;

CREATE OR REPLACE FUNCTION public._domino_play_as(_game_id uuid, _slot integer, _move jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  g             record;
  st            jsonb;
  hand          jsonb;
  tile          jsonb;
  placed_tile   jsonb;
  a int; b int;
  ha int; hb int;
  le int; re int;
  side          text;
  new_left      int;
  new_right     int;
  action        text;
  n_players     int;
  next_turn     int;
  drawn         jsonb;
  stock         jsonb;
  found         boolean := false;
  new_hand      jsonb;
  i             int;
  winner_slot   int;
  draw_mode     text;
  first_dbl     int;
  first_rule    text;
  stock_len     int;
  actor_is_bot  boolean;
  norm          jsonb;
  turn_secs     int;
BEGIN
  PERFORM public._domino_lock_game(_game_id);

  SELECT * INTO g FROM public.domino_games WHERE id = _game_id FOR UPDATE;
  IF g.status <> 'playing' THEN RAISE EXCEPTION 'game not active'; END IF;
  IF _slot <> g.current_turn THEN RAISE EXCEPTION 'not your turn (slot %, expected %)', _slot, g.current_turn; END IF;

  SELECT COALESCE(turn_timer_seconds, 60) INTO turn_secs
    FROM public.game_configs WHERE slug = 'domino';
  IF turn_secs IS NULL THEN turn_secs := 60; END IF;

  st := g.state;
  IF COALESCE(st->>'phase', 'play') NOT IN ('play', 'playing') THEN
    RAISE EXCEPTION 'round transition in progress';
  END IF;

  norm      := public._domino_normalize_board(COALESCE(st->'board', '[]'::jsonb));
  st        := jsonb_set(st, '{board}', COALESCE(norm->'board', '[]'::jsonb), true);
  st        := jsonb_set(st, '{left_end}', COALESCE(norm->'left_end', 'null'::jsonb), true);
  st        := jsonb_set(st, '{right_end}', COALESCE(norm->'right_end', 'null'::jsonb), true);

  action    := _move->>'action';
  hand      := COALESCE(st -> 'hands' -> _slot::text, '[]'::jsonb);
  stock     := COALESCE(st -> 'stock', '[]'::jsonb);
  le        := NULLIF(st->>'left_end',  'null')::int;
  re        := NULLIF(st->>'right_end', 'null')::int;
  draw_mode := COALESCE(st->>'draw_mode', 'with');
  first_rule := COALESCE(st->>'first_tile_rule', 'libre');
  stock_len := jsonb_array_length(stock);

  SELECT count(*) INTO n_players FROM public.domino_participants WHERE game_id = _game_id AND forfeited = false;
  SELECT is_bot INTO actor_is_bot
    FROM public.domino_participants WHERE game_id = _game_id AND slot = _slot;

  st := st - 'bot_think_until' - 'bot_locked_slot';

  IF COALESCE(actor_is_bot,false) AND action IN ('play','pass') THEN
    st := jsonb_set(st, '{bot_last_play_at}', to_jsonb(now()::text), true);
  END IF;

  IF action = 'draw' THEN
    IF draw_mode = 'without' THEN RAISE EXCEPTION 'draw disabled in this game'; END IF;
    IF public._domino_slot_has_playable(st, _slot) THEN RAISE EXCEPTION 'play your playable domino first'; END IF;
    IF stock_len = 0 THEN RAISE EXCEPTION 'stock empty'; END IF;
    drawn := stock -> 0;
    stock := stock - 0;
    hand  := hand || jsonb_build_array(drawn);
    st := jsonb_set(st, ARRAY['hands', _slot::text], hand, true);
    st := jsonb_set(st, '{stock}', stock, true);
    UPDATE public.domino_games SET state = st WHERE id = _game_id;
    RETURN;
  END IF;

  IF action = 'pass' THEN
    IF public._domino_slot_has_playable(st, _slot) THEN RAISE EXCEPTION 'you have a playable domino'; END IF;
    IF draw_mode = 'with' AND stock_len > 0 THEN RAISE EXCEPTION 'you must draw first'; END IF;
    st        := jsonb_set(st, '{passes}', to_jsonb(COALESCE((st->>'passes')::int, 0) + 1), true);
    st        := jsonb_set(st, '{last_pass_by}', to_jsonb(_slot), true);
    next_turn := public._domino_next_playable_slot(_game_id, _slot, st);
    IF (st->>'passes')::int >= n_players THEN
      UPDATE public.domino_games SET state = st WHERE id = _game_id;
      winner_slot := public._domino_lowest_pip_slot(_game_id, st);
      PERFORM public._domino_end_round(_game_id, winner_slot);
      RETURN;
    END IF;
    IF next_turn IS NULL THEN
      UPDATE public.domino_games SET state = st WHERE id = _game_id;
      winner_slot := public._domino_lowest_pip_slot(_game_id, st);
      PERFORM public._domino_end_round(_game_id, winner_slot);
      RETURN;
    END IF;
    st := jsonb_set(st, '{current_turn}', to_jsonb(next_turn), true);
    st := public._domino_turn_state(st, turn_secs);
    st := public._domino_arm_bot_think(_game_id, next_turn, st);
    UPDATE public.domino_games
       SET state = st,
           current_turn = next_turn,
           turn_deadline = now() + (turn_secs || ' seconds')::interval
     WHERE id = _game_id;
    RETURN;
  END IF;

  IF action <> 'play' THEN RAISE EXCEPTION 'unknown action %', action; END IF;

  tile := _move -> 'tile';
  IF tile IS NULL OR jsonb_typeof(tile) <> 'array' OR jsonb_array_length(tile) <> 2 THEN
    RAISE EXCEPTION 'tile required';
  END IF;
  a := (tile->>0)::int;
  b := (tile->>1)::int;
  side := NULLIF(_move->>'side', 'auto');

  found := false;
  FOR i IN 0 .. jsonb_array_length(hand) - 1 LOOP
    ha := (hand->i->>0)::int;
    hb := (hand->i->>1)::int;
    IF (ha = a AND hb = b) OR (ha = b AND hb = a) THEN
      found := true;
      a := ha;
      b := hb;
      new_hand := hand - i;
      EXIT;
    END IF;
  END LOOP;
  IF NOT found THEN RAISE EXCEPTION 'tile [% %] not in hand of slot %', a, b, _slot; END IF;

  first_dbl := NULLIF(st->>'first_move_double', 'null')::int;
  IF le IS NULL THEN
    IF first_dbl IS NOT NULL AND (a <> first_dbl OR b <> first_dbl) THEN
      RAISE EXCEPTION 'first move must be the highest double';
    END IF;
    IF first_dbl IS NULL AND first_rule = 'under6' AND (a + b) >= 6 THEN
      RAISE EXCEPTION 'first domino must be under 6 points';
    END IF;
    new_left := a;
    new_right := b;
    placed_tile := jsonb_build_array(a, b);
    st := jsonb_set(st, '{board}', jsonb_build_array(jsonb_build_object('tile', placed_tile, 'flipped', false)), true);
  ELSE
    IF side IS NULL THEN
      IF a = re OR b = re THEN side := 'right';
      ELSIF a = le OR b = le THEN side := 'left';
      ELSE RAISE EXCEPTION 'tile does not fit';
      END IF;
    END IF;

    IF side = 'right' THEN
      IF a = re THEN placed_tile := jsonb_build_array(a, b); new_right := b;
      ELSIF b = re THEN placed_tile := jsonb_build_array(b, a); new_right := a;
      ELSE RAISE EXCEPTION 'tile does not fit right';
      END IF;
      new_left := le;
      st := jsonb_set(st, '{board}', COALESCE(st->'board', '[]'::jsonb) || jsonb_build_array(jsonb_build_object('tile', placed_tile, 'flipped', false)), true);
    ELSIF side = 'left' THEN
      IF a = le THEN placed_tile := jsonb_build_array(b, a); new_left := b;
      ELSIF b = le THEN placed_tile := jsonb_build_array(a, b); new_left := a;
      ELSE RAISE EXCEPTION 'tile does not fit left';
      END IF;
      new_right := re;
      st := jsonb_set(st, '{board}', jsonb_build_array(jsonb_build_object('tile', placed_tile, 'flipped', false)) || COALESCE(st->'board', '[]'::jsonb), true);
    ELSE
      RAISE EXCEPTION 'invalid side';
    END IF;
  END IF;

  st := jsonb_set(st, ARRAY['hands', _slot::text], new_hand, true);
  st := jsonb_set(st, '{left_end}',  to_jsonb(new_left), true);
  st := jsonb_set(st, '{right_end}', to_jsonb(new_right), true);
  st := jsonb_set(st, '{passes}',    to_jsonb(0), true);
  st := jsonb_set(st, '{first_move_double}', 'null'::jsonb, true);
  st := st - 'last_pass_by';

  IF jsonb_array_length(new_hand) = 0 THEN
    UPDATE public.domino_games SET state = st WHERE id = _game_id;
    PERFORM public._domino_end_round(_game_id, _slot);
    RETURN;
  END IF;

  next_turn := public._domino_next_playable_slot(_game_id, _slot, st);
  IF next_turn IS NULL THEN
    UPDATE public.domino_games SET state = st WHERE id = _game_id;
    winner_slot := public._domino_lowest_pip_slot(_game_id, st);
    PERFORM public._domino_end_round(_game_id, winner_slot);
    RETURN;
  END IF;

  st := jsonb_set(st, '{current_turn}', to_jsonb(next_turn), true);
  st := public._domino_turn_state(st, turn_secs);
  st := public._domino_arm_bot_think(_game_id, next_turn, st);
  UPDATE public.domino_games
     SET state = st,
         current_turn = next_turn,
         turn_deadline = now() + (turn_secs || ' seconds')::interval
   WHERE id = _game_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._domino_purge(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  DELETE FROM public.chat_rooms WHERE game_id = _game_id;
  DELETE FROM public.game_spectators WHERE game_id = _game_id;
  DELETE FROM public.game_invitations WHERE game_id = _game_id;
  DELETE FROM public.domino_participants WHERE game_id = _game_id;
  DELETE FROM public.domino_games WHERE id = _game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public._domino_required_starter_slot(_game_id uuid, _state jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  first_dbl integer;
  p record;
  t jsonb;
BEGIN
  IF jsonb_array_length(COALESCE(_state->'board', '[]'::jsonb)) > 0 THEN
    RETURN NULL;
  END IF;

  first_dbl := NULLIF(_state->>'first_move_double', 'null')::integer;
  IF first_dbl IS NULL THEN
    RETURN NULL;
  END IF;

  FOR p IN
    SELECT slot
    FROM public.domino_participants
    WHERE game_id = _game_id
      AND forfeited = false
    ORDER BY slot
  LOOP
    FOR t IN SELECT * FROM jsonb_array_elements(COALESCE(_state->'hands'->p.slot::text, '[]'::jsonb)) LOOP
      IF (t->>0)::integer = first_dbl AND (t->>1)::integer = first_dbl THEN
        RETURN p.slot;
      END IF;
    END LOOP;
  END LOOP;

  RETURN NULL;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._domino_slot_has_playable(_state jsonb, _slot integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  hand jsonb := COALESCE(_state -> 'hands' -> _slot::text, '[]'::jsonb);
  board_len integer := jsonb_array_length(COALESCE(_state -> 'board', '[]'::jsonb));
  first_dbl integer;
  first_rule text;
  le integer;
  re integer;
  t jsonb;
  a integer;
  b integer;
BEGIN
  IF jsonb_array_length(hand) = 0 THEN
    RETURN false;
  END IF;

  IF board_len = 0 THEN
    first_dbl := NULLIF(_state->>'first_move_double', 'null')::integer;
    first_rule := COALESCE(_state->>'first_tile_rule', 'libre');

    IF first_dbl IS NOT NULL THEN
      FOR t IN SELECT * FROM jsonb_array_elements(hand) LOOP
        a := (t->>0)::integer; b := (t->>1)::integer;
        IF a = first_dbl AND b = first_dbl THEN RETURN true; END IF;
      END LOOP;
      RETURN false;
    END IF;

    IF first_rule = 'under6' THEN
      FOR t IN SELECT * FROM jsonb_array_elements(hand) LOOP
        a := (t->>0)::integer; b := (t->>1)::integer;
        IF (a + b) < 6 THEN RETURN true; END IF;
      END LOOP;
      RETURN false;
    END IF;

    RETURN true;
  END IF;

  le := NULLIF(_state->>'left_end', 'null')::integer;
  re := NULLIF(_state->>'right_end', 'null')::integer;

  FOR t IN SELECT * FROM jsonb_array_elements(hand) LOOP
    a := (t->>0)::integer;
    b := (t->>1)::integer;
    IF a = le OR b = le OR a = re OR b = re THEN RETURN true; END IF;
  END LOOP;

  RETURN false;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._domino_start(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  UPDATE public.domino_games
     SET status = 'playing',
         started_at = COALESCE(started_at, now()),
         turn_skips = '{}'::jsonb,
         scores = COALESCE(scores, '{}'::jsonb)
   WHERE id = _game_id
     AND status = 'open';

  IF NOT FOUND THEN RETURN; END IF;

  PERFORM public._domino_next_round(_game_id);
END;
$function$
;

-- ═══════════ 0007_functions_02.sql ═══════════
-- 0007_functions_02.sql
-- Fonctions et procédures (2/12)

CREATE OR REPLACE FUNCTION public._domino_turn_state(_state jsonb, _turn_seconds integer)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  SELECT jsonb_set(
           jsonb_set(
             COALESCE(_state, '{}'::jsonb),
             '{turn_started_at}',
             to_jsonb(now()::text),
             true
           ),
           '{turn_duration_seconds}',
           to_jsonb(GREATEST(1, COALESCE(_turn_seconds, 60))),
           true
         );
$function$
;

CREATE OR REPLACE FUNCTION public._domino_visible(_game_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS(
    SELECT 1 FROM public.domino_games g
    WHERE g.id = _game_id
      AND (
        (g.status IN ('open','playing') AND g.is_private = false)
        OR g.host_id = auth.uid()
        OR EXISTS(SELECT 1 FROM public.domino_participants p WHERE p.game_id = g.id AND p.user_id = auth.uid())
        OR public.is_admin()
      )
  )
$function$
;

CREATE OR REPLACE FUNCTION public._end_bot_only_games()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT g.id FROM public.ludo_games g
    WHERE g.status='playing' AND COALESCE(g.is_solo,false)=false
      AND NOT EXISTS (
        SELECT 1 FROM public.ludo_participants p
        WHERE p.game_id=g.id AND p.is_bot=false
          AND COALESCE(p.forfeited,false)=false
          AND p.finish_rank IS NULL
      )
  LOOP
    UPDATE public.ludo_games SET status='finished', finished_at=now() WHERE id=r.id AND status='playing';
  END LOOP;

  FOR r IN
    SELECT g.id FROM public.domino_games g
    WHERE g.status='playing'
      AND NOT EXISTS (SELECT 1 FROM public.domino_participants p WHERE p.game_id=g.id AND p.is_bot=false AND COALESCE(p.forfeited,false)=false)
  LOOP
    UPDATE public.domino_games SET status='finished', finished_at=now() WHERE id=r.id AND status='playing';
  END LOOP;

  FOR r IN
    SELECT g.id FROM public.fanorona_games g
    WHERE g.status='playing'
      AND NOT EXISTS (SELECT 1 FROM public.fanorona_participants p WHERE p.game_id=g.id AND p.is_bot=false AND COALESCE(p.forfeited,false)=false)
  LOOP
    UPDATE public.fanorona_games SET status='finished', finished_at=now() WHERE id=r.id AND status='playing';
  END LOOP;

  FOR r IN
    SELECT g.id FROM public.rami_games g
    WHERE g.status='playing'
      AND NOT EXISTS (SELECT 1 FROM public.rami_participants p WHERE p.game_id=g.id AND p.is_bot=false AND COALESCE(p.forfeited,false)=false)
  LOOP
    UPDATE public.rami_games SET status='finished', finished_at=now() WHERE id=r.id AND status='playing';
  END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION public._fanorona_apply_move(_game_id uuid, _slot integer, _move jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  g record;
  my_color int; opp_color int;
  st jsonb; board jsonb;
  from_idx int; to_idx int;
  fr int; fc int; tr int; tc int; dr int; dc int;
  is_strong boolean;
  cap jsonb; lists jsonb;
  opp_left int; next_turn int;
  is_pass boolean;
  move_count int;
  visited jsonb;
  last_axis text;
  axis text;
  chain_from_v int;
  i int;
  v_cols int; v_rows int;
BEGIN
  SELECT * INTO g FROM public.fanorona_games WHERE id = _game_id FOR UPDATE;
  IF g.status <> 'playing' THEN RAISE EXCEPTION 'game not active'; END IF;
  IF _slot <> g.current_turn THEN RAISE EXCEPTION 'not this slot''s turn'; END IF;

  v_cols := COALESCE(g.cols, 9); v_rows := COALESCE(g.rows, 5);
  my_color  := CASE WHEN _slot = 0 THEN 1 ELSE 2 END;
  opp_color := CASE WHEN _slot = 0 THEN 2 ELSE 1 END;
  st        := g.state;
  board     := st -> 'board';
  move_count := COALESCE((st->>'move_count')::int, 0);
  visited    := COALESCE(st->'visited', '[]'::jsonb);
  last_axis  := NULLIF(st->>'last_axis', '');
  chain_from_v := CASE WHEN st->'chain_from' IS NULL OR st->'chain_from' = 'null'::jsonb
                       THEN NULL ELSE (st->>'chain_from')::int END;
  is_pass := COALESCE((_move->>'pass')::boolean, false);

  IF is_pass THEN
    next_turn := 1 - _slot;
    st := jsonb_set(st, '{chain_from}', 'null'::jsonb);
    st := jsonb_set(st, '{visited}',    '[]'::jsonb);
    st := jsonb_set(st, '{last_axis}',  'null'::jsonb);
    st := jsonb_set(st, '{move_count}', to_jsonb(move_count + 1));
    UPDATE public.fanorona_games SET state = st, current_turn = next_turn,
      turn_deadline = now() + (COALESCE((SELECT turn_timer_seconds FROM public._game_cfg('fanorona')),60) || ' seconds')::interval
      WHERE id = _game_id;
    IF NOT public._fanorona_player_has_move(board, opp_color, v_cols, v_rows) THEN
      PERFORM public._fanorona_finalize(_game_id, _slot);
    END IF;
    RETURN;
  END IF;

  from_idx := (_move->>'from')::int;
  to_idx   := (_move->>'to')::int;
  cap      := COALESCE(_move->'captured', '[]'::jsonb);

  IF chain_from_v IS NOT NULL AND from_idx <> chain_from_v THEN
    RAISE EXCEPTION 'must continue with same piece';
  END IF;
  IF (board->from_idx)::int <> my_color THEN RAISE EXCEPTION 'not your piece'; END IF;
  IF (board->to_idx)::int <> 0 THEN RAISE EXCEPTION 'target not empty'; END IF;

  fr := from_idx / v_cols; fc := from_idx % v_cols;
  tr := to_idx   / v_cols; tc := to_idx   % v_cols;
  dr := tr - fr;           dc := tc - fc;
  IF abs(dr) > 1 OR abs(dc) > 1 OR (dr = 0 AND dc = 0) THEN
    RAISE EXCEPTION 'invalid step';
  END IF;
  is_strong := ((fr + fc) % 2 = 0);
  IF NOT is_strong AND (dr <> 0 AND dc <> 0) THEN
    RAISE EXCEPTION 'diagonal not allowed here';
  END IF;
  axis := public._fanorona_axis(dr, dc);
  IF chain_from_v IS NOT NULL THEN
    IF visited @> to_jsonb(to_idx) THEN RAISE EXCEPTION 'cannot revisit cell'; END IF;
    IF last_axis IS NOT NULL AND axis = last_axis THEN
      RAISE EXCEPTION 'cannot continue on same axis';
    END IF;
  END IF;

  lists := public._fanorona_capture_lists(board, my_color, from_idx, to_idx, v_cols, v_rows);
  IF jsonb_array_length(cap) > 0 THEN
    IF NOT (cap = (lists->'approach') OR cap = (lists->'withdrawal')) THEN
      RAISE EXCEPTION 'invalid capture set';
    END IF;
  END IF;
  IF jsonb_array_length(cap) = 0 THEN
    IF chain_from_v IS NOT NULL THEN RAISE EXCEPTION 'must capture during chain'; END IF;
    IF COALESCE(g.mandatory_capture, true)
       AND public._fanorona_player_can_capture(board, my_color, v_cols, v_rows) THEN
      RAISE EXCEPTION 'capture is mandatory when available';
    END IF;
  END IF;

  board := jsonb_set(board, ARRAY[from_idx::text], '0'::jsonb);
  board := jsonb_set(board, ARRAY[to_idx::text],   to_jsonb(my_color));
  IF jsonb_array_length(cap) > 0 THEN
    FOR i IN 0..jsonb_array_length(cap) - 1 LOOP
      board := jsonb_set(board, ARRAY[((cap->i)::int)::text], '0'::jsonb);
    END LOOP;
  END IF;
  st := jsonb_set(st, '{board}', board);

  SELECT count(*) INTO opp_left FROM jsonb_array_elements(board) v
    WHERE (v::text)::int = opp_color;
  IF opp_left = 0 THEN
    UPDATE public.fanorona_games SET state = st WHERE id = _game_id;
    PERFORM public._fanorona_finalize(_game_id, _slot);
    RETURN;
  END IF;

  IF jsonb_array_length(cap) = 0 THEN
    next_turn := 1 - _slot;
    st := jsonb_set(st, '{chain_from}', 'null'::jsonb);
    st := jsonb_set(st, '{visited}',    '[]'::jsonb);
    st := jsonb_set(st, '{last_axis}',  'null'::jsonb);
    st := jsonb_set(st, '{move_count}', to_jsonb(move_count + 1));
  ELSE
    IF move_count = 0 THEN
      next_turn := 1 - _slot;
      st := jsonb_set(st, '{chain_from}', 'null'::jsonb);
      st := jsonb_set(st, '{visited}',    '[]'::jsonb);
      st := jsonb_set(st, '{last_axis}',  'null'::jsonb);
      st := jsonb_set(st, '{move_count}', to_jsonb(move_count + 1));
    ELSE
      visited := visited || to_jsonb(from_idx) || to_jsonb(to_idx);
      IF public._fanorona_piece_can_capture(board, my_color, to_idx, visited, axis, v_cols, v_rows) THEN
        next_turn := _slot;
        st := jsonb_set(st, '{chain_from}', to_jsonb(to_idx));
        st := jsonb_set(st, '{visited}',    visited);
        st := jsonb_set(st, '{last_axis}',  to_jsonb(axis));
      ELSE
        next_turn := 1 - _slot;
        st := jsonb_set(st, '{chain_from}', 'null'::jsonb);
        st := jsonb_set(st, '{visited}',    '[]'::jsonb);
        st := jsonb_set(st, '{last_axis}',  'null'::jsonb);
        st := jsonb_set(st, '{move_count}', to_jsonb(move_count + 1));
      END IF;
    END IF;
  END IF;

  UPDATE public.fanorona_games SET state = st, current_turn = next_turn,
    turn_deadline = now() + (COALESCE((SELECT turn_timer_seconds FROM public._game_cfg('fanorona')),60) || ' seconds')::interval
    WHERE id = _game_id;

  IF next_turn = 1 - _slot
     AND NOT public._fanorona_player_has_move(board, opp_color, v_cols, v_rows) THEN
    PERFORM public._fanorona_finalize(_game_id, _slot);
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public._fanorona_axis(_dr integer, _dc integer)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE WHEN _dr < 0 OR (_dr = 0 AND _dc < 0)
              THEN (-_dr)::text || ',' || (-_dc)::text
              ELSE _dr::text || ',' || _dc::text END
$function$
;

CREATE OR REPLACE FUNCTION public._fanorona_bot_pick_move(_game_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  g record;
  st jsonb; board jsonb;
  my_slot int; my_color int; opp_color int;
  v_cols int; v_rows int;
  chain_from_v int; visited jsonb; last_axis text;
  must_capture boolean;
  cell int; r int; c int; is_strong boolean;
  dr int; dc int; nr int; nc int; nidx int;
  lists jsonb;
  best jsonb := NULL; best_score numeric := -1e18; score numeric;
  candidate jsonb;
  cap_variants text[]; variant text;
  cap jsonb; cap_len int;
  intel int;
  is_chain boolean;
  found_any boolean := false;
  after_board jsonb; after_visited jsonb; can_continue boolean;
BEGIN
  SELECT * INTO g FROM public.fanorona_games WHERE id = _game_id;
  IF g.status <> 'playing' THEN RETURN NULL; END IF;
  my_slot := g.current_turn;
  SELECT COALESCE(bot_intelligence, 2) INTO intel
    FROM public.fanorona_participants
    WHERE game_id = _game_id AND slot = my_slot AND is_bot = true;
  IF intel IS NULL THEN RETURN NULL; END IF;

  v_cols := COALESCE(g.cols, 9); v_rows := COALESCE(g.rows, 5);
  my_color  := CASE WHEN my_slot = 0 THEN 1 ELSE 2 END;
  opp_color := CASE WHEN my_slot = 0 THEN 2 ELSE 1 END;
  st := g.state; board := st->'board';
  visited   := COALESCE(st->'visited', '[]'::jsonb);
  last_axis := NULLIF(st->>'last_axis', '');
  chain_from_v := CASE WHEN st->'chain_from' IS NULL OR st->'chain_from'='null'::jsonb
                       THEN NULL ELSE (st->>'chain_from')::int END;
  is_chain := chain_from_v IS NOT NULL;
  must_capture := COALESCE(g.mandatory_capture, true)
                  AND public._fanorona_player_can_capture(board, my_color, v_cols, v_rows);

  -- Iterate pieces (or just chain piece)
  FOR cell IN
    SELECT gs FROM generate_series(0, v_cols*v_rows - 1) gs
    WHERE (is_chain AND gs = chain_from_v)
       OR (NOT is_chain AND (board->gs)::int = my_color)
  LOOP
    r := cell / v_cols; c := cell % v_cols;
    is_strong := ((r + c) % 2 = 0);
    FOR dr, dc IN
      SELECT a,b FROM (VALUES (-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)) v(a,b)
    LOOP
      IF NOT is_strong AND (dr <> 0 AND dc <> 0) THEN CONTINUE; END IF;
      nr := r + dr; nc := c + dc;
      IF nr < 0 OR nr >= v_rows OR nc < 0 OR nc >= v_cols THEN CONTINUE; END IF;
      nidx := nr * v_cols + nc;
      IF (board->nidx)::int <> 0 THEN CONTINUE; END IF;
      IF is_chain THEN
        IF visited @> to_jsonb(nidx) THEN CONTINUE; END IF;
        IF last_axis IS NOT NULL AND public._fanorona_axis(dr, dc) = last_axis THEN CONTINUE; END IF;
      END IF;

      lists := public._fanorona_capture_lists(board, my_color, cell, nidx, v_cols, v_rows);
      -- Build the set of capture variants for this (from,to)
      cap_variants := ARRAY[]::text[];
      IF jsonb_array_length(lists->'approach') > 0   THEN cap_variants := cap_variants || 'a'; END IF;
      IF jsonb_array_length(lists->'withdrawal') > 0 THEN cap_variants := cap_variants || 'w'; END IF;
      -- Non-capture is allowed only when not in a chain AND (no mandatory capture OR no capture exists)
      IF NOT is_chain AND (cap_variants = ARRAY[]::text[] OR NOT must_capture) THEN
        cap_variants := cap_variants || 'n';
      END IF;

      FOREACH variant IN ARRAY cap_variants LOOP
        IF variant = 'a' THEN cap := lists->'approach';
        ELSIF variant = 'w' THEN cap := lists->'withdrawal';
        ELSE cap := '[]'::jsonb;
        END IF;
        cap_len := jsonb_array_length(cap);
        IF must_capture AND cap_len = 0 THEN CONTINUE; END IF;

        -- Score: captures dominate. Facile: mostly random. Moyen: greedy.
        -- Difficile: greedy + bonus if the destination can chain further.
        can_continue := false;
        IF cap_len > 0 AND intel >= 3 THEN
          after_board := jsonb_set(board, ARRAY[cell::text], '0'::jsonb);
          after_board := jsonb_set(after_board, ARRAY[nidx::text], to_jsonb(my_color));
          FOR i IN 0..cap_len - 1 LOOP
            after_board := jsonb_set(after_board, ARRAY[((cap->i)::int)::text], '0'::jsonb);
          END LOOP;
          after_visited := visited || to_jsonb(cell) || to_jsonb(nidx);
          can_continue := public._fanorona_piece_can_capture(
            after_board, my_color, nidx, after_visited,
            public._fanorona_axis(dr,dc), v_cols, v_rows);
        END IF;

        score := CASE
          WHEN intel <= 1 THEN random() + cap_len * 0.5
          WHEN intel = 2  THEN cap_len * 10 + random()
          ELSE cap_len * 10 + (CASE WHEN can_continue THEN 3 ELSE 0 END) + random() * 0.5
        END;

        IF score > best_score THEN
          best_score := score;
          best := jsonb_build_object('from', cell, 'to', nidx, 'captured', cap);
          found_any := true;
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  IF NOT found_any THEN RETURN jsonb_build_object('pass', true); END IF;
  RETURN best;
END $function$
;

CREATE OR REPLACE FUNCTION public._fanorona_capture_lists(_board jsonb, _my integer, _from integer, _to integer)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT public._fanorona_capture_lists(_board, _my, _from, _to, 9, 5);
$function$
;

CREATE OR REPLACE FUNCTION public._fanorona_capture_lists(_board jsonb, _my integer, _from integer, _to integer, _cols integer, _rows integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  opp int := CASE WHEN _my = 1 THEN 2 ELSE 1 END;
  fr int := _from / _cols; fc int := _from % _cols;
  tr int := _to / _cols;   tc int := _to % _cols;
  dr int := tr - fr;       dc int := tc - fc;
  ap jsonb := '[]'::jsonb; wd jsonb := '[]'::jsonb;
  r int; c int; idx int;
BEGIN
  r := tr + dr; c := tc + dc;
  WHILE r >= 0 AND r < _rows AND c >= 0 AND c < _cols LOOP
    idx := r * _cols + c;
    EXIT WHEN (_board->idx)::int <> opp;
    ap := ap || to_jsonb(idx);
    r := r + dr; c := c + dc;
  END LOOP;
  r := fr - dr; c := fc - dc;
  WHILE r >= 0 AND r < _rows AND c >= 0 AND c < _cols LOOP
    idx := r * _cols + c;
    EXIT WHEN (_board->idx)::int <> opp;
    wd := wd || to_jsonb(idx);
    r := r - dr; c := c - dc;
  END LOOP;
  RETURN jsonb_build_object('approach', ap, 'withdrawal', wd);
END $function$
;

CREATE OR REPLACE FUNCTION public._fanorona_draw_refund(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g record; p record;
BEGIN
  SELECT * INTO g FROM public.fanorona_games WHERE id = _game_id FOR UPDATE;
  IF g.status <> 'playing' THEN RETURN; END IF;
  IF g.stake > 0 THEN
    FOR p IN SELECT user_id FROM public.fanorona_participants WHERE game_id = _game_id LOOP
      UPDATE public.profiles SET balance_ar = balance_ar + g.stake WHERE id = p.user_id;
      INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
        VALUES (p.user_id, 'fanorona_refund', g.stake, _game_id, 'Fanorona draw (Vasa)');
    END LOOP;
  END IF;
  UPDATE public.fanorona_games
     SET status = 'draw', finished_at = now(), winner_id = NULL
   WHERE id = _game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public._fanorona_finalize(_game_id uuid, _winner_slot integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g record; winner_uid uuid; payout numeric;
BEGIN
  SELECT * INTO g FROM public.fanorona_games WHERE id = _game_id FOR UPDATE;
  IF g.status = 'finished' THEN RETURN; END IF;
  SELECT user_id INTO winner_uid FROM public.fanorona_participants WHERE game_id = _game_id AND slot = _winner_slot;
  payout := g.pot * (100 - g.commission_pct) / 100;
  IF winner_uid IS NOT NULL THEN
    UPDATE public.profiles SET balance_ar = balance_ar + payout WHERE id = winner_uid;
    INSERT INTO public.transactions(user_id, type, amount, ref_id, note) VALUES (winner_uid, 'fanorona_win', payout, _game_id, 'Fanorona win');
  END IF;
  UPDATE public.fanorona_games SET status = 'finished', winner_id = winner_uid, finished_at = now() WHERE id = _game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public._fanorona_init_board()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT public._fanorona_init_board(9, 5);
$function$
;

CREATE OR REPLACE FUNCTION public._fanorona_init_board(_cols integer, _rows integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  r int; c int; mid int; v int;
  arr jsonb := '[]'::jsonb;
BEGIN
  mid := _rows / 2;
  FOR r IN 0.._rows - 1 LOOP
    FOR c IN 0.._cols - 1 LOOP
      IF r < mid THEN v := 2;
      ELSIF r > mid THEN v := 1;
      ELSE
        -- middle row: alternate, with centre empty
        IF c = _cols / 2 THEN v := 0;
        ELSIF ((c < _cols / 2) = (c % 2 = 0)) THEN v := 1; ELSE v := 2;
        END IF;
      END IF;
      arr := arr || to_jsonb(v);
    END LOOP;
  END LOOP;
  RETURN arr;
END $function$
;

CREATE OR REPLACE FUNCTION public._fanorona_piece_can_capture(_board jsonb, _my integer, _idx integer, _visited jsonb, _last_axis text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT public._fanorona_piece_can_capture(_board, _my, _idx, _visited, _last_axis, 9, 5);
$function$
;

CREATE OR REPLACE FUNCTION public._fanorona_piece_can_capture(_board jsonb, _my integer, _idx integer, _visited jsonb, _last_axis text, _cols integer, _rows integer)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  r int := _idx / _cols; c int := _idx % _cols;
  is_strong boolean := ((r + c) % 2 = 0);
  dr int; dc int; nr int; nc int; nidx int;
  axis text; lists jsonb;
BEGIN
  FOR dr, dc IN
    SELECT a, b FROM (VALUES (-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)) v(a,b)
  LOOP
    IF NOT is_strong AND (dr <> 0 AND dc <> 0) THEN CONTINUE; END IF;
    nr := r + dr; nc := c + dc;
    IF nr < 0 OR nr >= _rows OR nc < 0 OR nc >= _cols THEN CONTINUE; END IF;
    nidx := nr * _cols + nc;
    IF (_board->nidx)::int <> 0 THEN CONTINUE; END IF;
    IF _visited @> to_jsonb(nidx) THEN CONTINUE; END IF;
    axis := public._fanorona_axis(dr, dc);
    IF _last_axis IS NOT NULL AND axis = _last_axis THEN CONTINUE; END IF;
    lists := public._fanorona_capture_lists(_board, _my, _idx, nidx, _cols, _rows);
    IF jsonb_array_length(lists->'approach') > 0
       OR jsonb_array_length(lists->'withdrawal') > 0 THEN
      RETURN true;
    END IF;
  END LOOP;
  RETURN false;
END $function$
;

CREATE OR REPLACE FUNCTION public._fanorona_player_can_capture(_board jsonb, _my integer)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT public._fanorona_player_can_capture(_board, _my, 9, 5);
$function$
;

CREATE OR REPLACE FUNCTION public._fanorona_player_can_capture(_board jsonb, _my integer, _cols integer, _rows integer)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE i int;
BEGIN
  FOR i IN 0..(_cols * _rows - 1) LOOP
    IF (_board->i)::int = _my
       AND public._fanorona_piece_can_capture(_board, _my, i, '[]'::jsonb, NULL, _cols, _rows) THEN
      RETURN true;
    END IF;
  END LOOP;
  RETURN false;
END $function$
;

CREATE OR REPLACE FUNCTION public._fanorona_player_has_move(_board jsonb, _my integer)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT public._fanorona_player_has_move(_board, _my, 9, 5);
$function$
;

CREATE OR REPLACE FUNCTION public._fanorona_player_has_move(_board jsonb, _my integer, _cols integer, _rows integer)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE i int; r int; c int; dr int; dc int; nr int; nc int;
BEGIN
  FOR i IN 0..(_cols * _rows - 1) LOOP
    IF (_board->i)::int <> _my THEN CONTINUE; END IF;
    r := i / _cols; c := i % _cols;
    FOR dr, dc IN
      SELECT a, b FROM (VALUES (-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)) v(a,b)
    LOOP
      IF (r + c) % 2 <> 0 AND (dr <> 0 AND dc <> 0) THEN CONTINUE; END IF;
      nr := r + dr; nc := c + dc;
      IF nr < 0 OR nr >= _rows OR nc < 0 OR nc >= _cols THEN CONTINUE; END IF;
      IF (_board->(nr * _cols + nc))::int = 0 THEN RETURN true; END IF;
    END LOOP;
  END LOOP;
  RETURN false;
END $function$
;

CREATE OR REPLACE FUNCTION public._fanorona_visible(_game_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS(
    SELECT 1 FROM public.fanorona_games g
    WHERE g.id = _game_id
      AND (
        (g.status IN ('open','playing') AND g.is_private = false)
        OR g.host_id = auth.uid()
        OR EXISTS(SELECT 1 FROM public.fanorona_participants p WHERE p.game_id = g.id AND p.user_id = auth.uid())
        OR public.is_admin()
      )
  )
$function$
;

CREATE OR REPLACE FUNCTION public._finance_tests_cleanup(_ids uuid[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  DELETE FROM public.ludo_participants WHERE user_id = ANY(_ids);
  DELETE FROM public.domino_participants WHERE user_id = ANY(_ids);
  DELETE FROM public.ludo_games WHERE host_id = ANY(_ids);
  DELETE FROM public.chess_games WHERE host_id = ANY(_ids) OR white_id = ANY(_ids) OR black_id = ANY(_ids);
  DELETE FROM public.domino_games WHERE host_id = ANY(_ids);
  DELETE FROM public.transactions WHERE user_id = ANY(_ids);
  DELETE FROM public.deposits WHERE user_id = ANY(_ids);
  DELETE FROM public.withdrawals WHERE user_id = ANY(_ids);
  DELETE FROM public.withdrawal_debts WHERE user_id = ANY(_ids);
  DELETE FROM public.notifications WHERE user_id = ANY(_ids);
  DELETE FROM public.user_roles WHERE user_id = ANY(_ids);
  DELETE FROM public.profiles WHERE id = ANY(_ids);
  DELETE FROM auth.users WHERE id = ANY(_ids);
END
$function$
;

CREATE OR REPLACE FUNCTION public._game_cfg(_slug text)
 RETURNS TABLE(turn_timer_seconds integer, max_turn_skips integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    COALESCE((SELECT gc.turn_timer_seconds FROM public.game_configs gc WHERE gc.slug=_slug), 60)::int,
    COALESCE((SELECT gc.max_turn_skips     FROM public.game_configs gc WHERE gc.slug=_slug), 5)::int;
$function$
;

CREATE OR REPLACE FUNCTION public._game_resume_internal(_slug text, _game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_status TEXT; v_paused BOOLEAN; v_remaining_s INTEGER;
BEGIN
  CASE _slug
    WHEN 'chess' THEN SELECT status, paused, paused_turn_remaining_s INTO v_status, v_paused, v_remaining_s FROM public.chess_games WHERE id = _game_id;
    WHEN 'fanorona' THEN SELECT status, paused, paused_turn_remaining_s INTO v_status, v_paused, v_remaining_s FROM public.fanorona_games WHERE id = _game_id;
    WHEN 'domino' THEN SELECT status, paused, paused_turn_remaining_s INTO v_status, v_paused, v_remaining_s FROM public.domino_games WHERE id = _game_id;
    WHEN 'rami' THEN SELECT status, paused, paused_turn_remaining_s INTO v_status, v_paused, v_remaining_s FROM public.rami_games WHERE id = _game_id;
    WHEN 'poker' THEN SELECT status, paused, paused_turn_remaining_s INTO v_status, v_paused, v_remaining_s FROM public.poker_games WHERE id = _game_id;
    WHEN 'ludo' THEN SELECT status, paused INTO v_status, v_paused FROM public.ludo_games WHERE id = _game_id;
    ELSE RAISE EXCEPTION 'slug invalide: %', _slug;
  END CASE;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_status <> 'playing' OR NOT v_paused THEN RETURN; END IF;
  CASE _slug
    WHEN 'chess' THEN UPDATE public.chess_games SET paused=FALSE, pause_deadline=NULL, paused_turn_remaining_s=NULL, turn_deadline = now() + (COALESCE(v_remaining_s,30) || ' seconds')::interval WHERE id = _game_id AND paused = TRUE AND status = 'playing';
    WHEN 'fanorona' THEN UPDATE public.fanorona_games SET paused=FALSE, pause_deadline=NULL, paused_turn_remaining_s=NULL, turn_deadline = now() + (COALESCE(v_remaining_s,60) || ' seconds')::interval WHERE id = _game_id AND paused = TRUE AND status = 'playing';
    WHEN 'domino' THEN UPDATE public.domino_games SET paused=FALSE, pause_deadline=NULL, paused_turn_remaining_s=NULL, turn_deadline = now() + (COALESCE(v_remaining_s,60) || ' seconds')::interval WHERE id = _game_id AND paused = TRUE AND status = 'playing';
    WHEN 'rami' THEN UPDATE public.rami_games SET paused=FALSE, pause_deadline=NULL, paused_turn_remaining_s=NULL, turn_deadline = now() + (COALESCE(v_remaining_s,45) || ' seconds')::interval WHERE id = _game_id AND paused = TRUE AND status = 'playing';
    WHEN 'poker' THEN UPDATE public.poker_games SET paused=FALSE, pause_deadline=NULL, paused_turn_remaining_s=NULL, turn_deadline = now() + (COALESCE(v_remaining_s,30) || ' seconds')::interval WHERE id = _game_id AND paused = TRUE AND status = 'playing';
    WHEN 'ludo' THEN UPDATE public.ludo_games SET paused=FALSE, pause_deadline=NULL, state = jsonb_set(state, '{turn_started_at}', to_jsonb(now()::text), true) WHERE id = _game_id AND paused = TRUE AND status = 'playing';
  END CASE;
END $function$
;

CREATE OR REPLACE FUNCTION public._game_visible(_game_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.ludo_games g
    WHERE g.id = _game_id
      AND (g.status IN ('open','playing')
           OR g.host_id = auth.uid()
           OR public._is_game_participant(g.id, auth.uid())
           OR public.is_admin())
  )
$function$
;

CREATE OR REPLACE FUNCTION public._gen_room_code()
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE c TEXT;
BEGIN
  LOOP
    c := upper(substring(replace(gen_random_uuid()::text,'-',''),1,6));
    IF NOT EXISTS (SELECT 1 FROM public.ludo_games WHERE room_code = c) THEN RETURN c; END IF;
  END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION public._grant_admin_for_seed_emails()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF lower(NEW.email) IN ('lalaomadaa@gmail.com','mrpierrit@gmail.com') THEN
    INSERT INTO public.user_roles(user_id, role)
    VALUES (NEW.id, 'admin'::app_role)
    ON CONFLICT (user_id, role) DO NOTHING;
  END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._guard_balance_non_negative()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.balance_ar < 0 THEN
    RAISE EXCEPTION 'Solde insuffisant (tentative de solde négatif: %)', NEW.balance_ar
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._is_game_participant(_game_id uuid, _user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    EXISTS (SELECT 1 FROM public.ludo_participants     WHERE game_id = _game_id AND user_id = _user_id)
 OR EXISTS (SELECT 1 FROM public.domino_participants   WHERE game_id = _game_id AND user_id = _user_id)
 OR EXISTS (SELECT 1 FROM public.fanorona_participants WHERE game_id = _game_id AND user_id = _user_id)
 OR EXISTS (SELECT 1 FROM public.rami_participants     WHERE game_id = _game_id AND user_id = _user_id)
 OR EXISTS (SELECT 1 FROM public.chess_games
              WHERE id = _game_id AND (white_id = _user_id OR black_id = _user_id))
$function$
;

CREATE OR REPLACE FUNCTION public._is_valid_email(_raw text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT _raw IS NULL OR btrim(_raw) = '' OR btrim(_raw) ~ '^[^\s@]+@[^\s@]+\.[^\s@]+$';
$function$
;

CREATE OR REPLACE FUNCTION public._is_valid_http_url(_raw text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT _raw IS NULL OR btrim(_raw) = '' OR btrim(_raw) ~* '^https?://[^\s]+$';
$function$
;

CREATE OR REPLACE FUNCTION public._is_valid_mg_phone(_raw text)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE d text;
BEGIN
  IF _raw IS NULL OR btrim(_raw) = '' THEN RETURN TRUE; END IF;
  d := regexp_replace(_raw, '[\s\.\-]', '', 'g');
  RETURN d ~ '^\+261[0-9]{9}$' OR d ~ '^0[23][0-9]{8}$';
END;$function$
;

CREATE OR REPLACE FUNCTION public._log_admin_action(_action text, _target_type text, _target_id uuid, _payload jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.admin_action_logs(admin_id, action, target_type, target_id, payload)
    VALUES (auth.uid(), _action, _target_type, _target_id, _payload);
END $function$
;

CREATE OR REPLACE FUNCTION public._log_house_on_finish()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_game_type text := TG_ARGV[0];
  v_pot numeric := COALESCE((row_to_json(NEW)->>'pot')::numeric, 0);
  v_pct numeric := COALESCE((row_to_json(NEW)->>'commission_pct')::numeric, 10);
  v_winner uuid := NULLIF((row_to_json(NEW)->>'winner_id'),'')::uuid;
  v_is_bot boolean := false;
  v_commission numeric;
BEGIN
  -- Only fire when status transitions to 'finished'
  IF NEW.status IS DISTINCT FROM 'finished' THEN RETURN NEW; END IF;
  IF OLD.status = 'finished' THEN RETURN NEW; END IF;
  IF v_pot IS NULL OR v_pot <= 0 THEN RETURN NEW; END IF;

  IF v_winner IS NULL THEN
    -- Draw / refund : no house income
    RETURN NEW;
  END IF;

  SELECT COALESCE(is_bot, false) INTO v_is_bot FROM public.profiles WHERE id = v_winner;

  IF v_is_bot THEN
    -- Bot won: platform captures the full pot
    INSERT INTO public.house_ledger(game_type, game_id, entry_type, amount, pot, commission_pct, winner_id, note)
    VALUES (v_game_type, NEW.id, 'house_win', v_pot, v_pot, v_pct, v_winner,
            'Gain maison — victoire bot');
  ELSE
    v_commission := round(v_pot * v_pct / 100.0);
    IF v_commission > 0 THEN
      INSERT INTO public.house_ledger(game_type, game_id, entry_type, amount, pot, commission_pct, winner_id, note)
      VALUES (v_game_type, NEW.id, 'commission', v_commission, v_pot, v_pct, v_winner,
              'Commission ' || v_pct || '% sur pot');
    END IF;
  END IF;

  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._ludo_active_humans(_game_id uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT count(*)::INT FROM public.ludo_participants
  WHERE game_id=_game_id AND is_bot=FALSE AND forfeited=FALSE
$function$
;

CREATE OR REPLACE FUNCTION public._ludo_advance_turn(_game_id uuid, _new_slot integer, _last_event text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g public.ludo_games%ROWTYPE;
  st jsonb;
  v_isbot boolean;
  v_spin_ms int;
  v_seq int;
  v_now text;
BEGIN
  SELECT * INTO g FROM public.ludo_games WHERE id=_game_id;
  st := g.state;
  v_now := to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"');
  SELECT is_bot INTO v_isbot FROM public.ludo_participants WHERE game_id=_game_id AND slot=_new_slot;
  v_spin_ms := CASE WHEN COALESCE(v_isbot, FALSE) THEN 2500 ELSE 0 END;
  v_seq := COALESCE((st->>'turn_seq')::int, 0) + 1;
  st := jsonb_set(st, '{turn_slot}',        to_jsonb(_new_slot));
  st := jsonb_set(st, '{turn_started_at}',  to_jsonb(v_now));
  st := jsonb_set(st, '{turn_seq}',         to_jsonb(v_seq));
  st := jsonb_set(st, '{phase}',            to_jsonb('spinning'::text));
  st := jsonb_set(st, '{phase_started_at}', to_jsonb(v_now));
  st := jsonb_set(st, '{spin_ms}',          to_jsonb(v_spin_ms));
  st := jsonb_set(st, '{dice}',             'null'::jsonb);
  st := jsonb_set(st, '{must_move}',        'false'::jsonb);
  st := jsonb_set(st, '{last_event}',       to_jsonb(_last_event));
  UPDATE public.ludo_games SET state=st, current_turn=_new_slot WHERE id=_game_id;
  RETURN st;
END $function$
;

CREATE OR REPLACE FUNCTION public._ludo_auto_move(_game_id uuid, _slot integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g public.ludo_games%ROWTYPE;
  v_dice int; v_playable jsonb; v_count int; v_pawn int;
  ii int; idx int; pawn jsonb; best_step int := -1;
BEGIN
  SELECT * INTO g FROM public.ludo_games WHERE id = _game_id;
  IF g.id IS NULL OR g.status <> 'playing' THEN RETURN false; END IF;
  IF NOT COALESCE(g.auto_move, false) THEN RETURN false; END IF;
  IF NOT COALESCE((g.state->>'must_move')::boolean, false) THEN RETURN false; END IF;
  v_dice := NULLIF(g.state->>'dice','null')::int;
  IF v_dice IS NULL THEN RETURN false; END IF;

  v_playable := public._ludo_playable_pawns(g.state->'pawns', _slot, v_dice);
  v_count := jsonb_array_length(COALESCE(v_playable, '[]'::jsonb));
  IF v_count = 0 THEN RETURN false; END IF;

  v_pawn := (v_playable->0)::int;
  IF v_dice = 6 THEN
    FOR ii IN 0..(v_count-1) LOOP
      idx := (v_playable->ii)::int;
      pawn := g.state->'pawns'->_slot::text->idx;
      IF pawn->>'s' = 'yard' THEN v_pawn := idx; EXIT; END IF;
    END LOOP;
  END IF;
  IF v_pawn = (v_playable->0)::int THEN
    FOR ii IN 0..(v_count-1) LOOP
      idx := (v_playable->ii)::int;
      pawn := g.state->'pawns'->_slot::text->idx;
      IF pawn->>'s' = 'track' AND (pawn->>'k')::int > best_step THEN
        best_step := (pawn->>'k')::int; v_pawn := idx;
      END IF;
    END LOOP;
  END IF;

  PERFORM set_config('app.ludo_auto', 'on', true);
  PERFORM public.ludo_move(_game_id, v_pawn);
  PERFORM set_config('app.ludo_auto', 'off', true);
  RETURN true;
END $function$
;

CREATE OR REPLACE FUNCTION public._ludo_check_afk(_game_id uuid, _slot integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_t1 int; v_t2 int; v_max1 int; v_max2 int;
  v_enabled boolean; v_uid uuid; v_isbot boolean; v_winner uuid;
BEGIN
  SELECT afk_enabled, afk_t1_max, afk_t2_max
    INTO v_enabled, v_max1, v_max2
    FROM public.app_settings WHERE id = 1;
  IF NOT COALESCE(v_enabled, TRUE) THEN RETURN; END IF;

  SELECT afk_t1, afk_t2, user_id, is_bot
    INTO v_t1, v_t2, v_uid, v_isbot
    FROM public.ludo_participants
   WHERE game_id = _game_id AND slot = _slot;
  IF v_isbot THEN RETURN; END IF;

  IF v_t1 >= COALESCE(v_max1, 2) OR v_t2 >= COALESCE(v_max2, 2) THEN
    UPDATE public.ludo_participants
       SET forfeited = TRUE
     WHERE game_id = _game_id AND slot = _slot;
    UPDATE public.ludo_games
       SET afk_warning = NULL, afk_pause_for = NULL, afk_pause_name = NULL
     WHERE id = _game_id;
    INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
      VALUES (v_uid, 'forfeit', 0, _game_id,
              'Exclusion AFK (T1=' || v_t1 || ' T2=' || v_t2 || ')');
    v_winner := public._ludo_check_last_standing(_game_id);
    IF v_winner IS NOT NULL THEN
      PERFORM public.finish_game(_game_id, v_winner);
    END IF;
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public._ludo_check_last_standing(_game_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE v_count INT; v_uid UUID;
BEGIN
  SELECT count(*) INTO v_count FROM public.ludo_participants
   WHERE game_id=_game_id AND forfeited=FALSE;
  IF v_count <= 1 THEN
    SELECT user_id INTO v_uid FROM public.ludo_participants
     WHERE game_id=_game_id AND forfeited=FALSE AND is_bot=FALSE LIMIT 1;
    RETURN v_uid;
  END IF;
  RETURN NULL;
END $function$
;

CREATE OR REPLACE FUNCTION public._ludo_ensure_state(_game_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE g public.ludo_games%ROWTYPE; st jsonb;
BEGIN
  SELECT * INTO g FROM public.ludo_games WHERE id=_game_id FOR UPDATE;
  IF g.status <> 'playing' THEN RAISE EXCEPTION 'Partie pas en cours'; END IF;
  IF (g.state ? 'pawns') IS NOT TRUE OR g.state->'pawns' = '{}'::jsonb THEN
    st := public._ludo_init_state(g.max_players);
    UPDATE public.ludo_games SET state=st, current_turn=0 WHERE id=_game_id;
    RETURN st;
  END IF;
  RETURN g.state;
END $function$
;

CREATE OR REPLACE FUNCTION public._ludo_init_state(_max_players integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE p jsonb := '{}'::jsonb; i INT;
BEGIN
  FOR i IN 0.._max_players-1 LOOP
    p := p || jsonb_build_object(i::text,
      jsonb_build_array(
        jsonb_build_object('s','yard','k',-1),
        jsonb_build_object('s','yard','k',-1),
        jsonb_build_object('s','yard','k',-1),
        jsonb_build_object('s','yard','k',-1)
      ));
  END LOOP;
  RETURN jsonb_build_object(
    'pawns', p, 'turn_slot', 0, 'dice', NULL, 'must_move', false,
    'turn_started_at', to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'last_event', 'start');
END $function$
;

CREATE OR REPLACE FUNCTION public._ludo_is_safe(_idx integer)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$ SELECT _idx IN (0,8,13,21,26,34,39,47) $function$
;

-- ═══════════ 0007_functions_03.sql ═══════════
-- 0007_functions_03.sql
-- Fonctions et procédures (3/12)

CREATE OR REPLACE FUNCTION public._ludo_next_slot(_game_id uuid, _from integer, _max integer)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE v_cur_start INT; v_next_slot INT;
BEGIN
  SELECT public._ludo_start_idx(CASE color WHEN 'red' THEN 0 WHEN 'green' THEN 1 WHEN 'yellow' THEN 2 WHEN 'blue' THEN 3 END)
    INTO v_cur_start FROM public.ludo_participants WHERE game_id = _game_id AND slot = _from;
  IF v_cur_start IS NULL THEN v_cur_start := 0; END IF;

  SELECT slot INTO v_next_slot FROM public.ludo_participants
   WHERE game_id = _game_id AND forfeited = FALSE AND finish_rank IS NULL
     AND public._ludo_start_idx(CASE color WHEN 'red' THEN 0 WHEN 'green' THEN 1 WHEN 'yellow' THEN 2 WHEN 'blue' THEN 3 END) > v_cur_start
   ORDER BY public._ludo_start_idx(CASE color WHEN 'red' THEN 0 WHEN 'green' THEN 1 WHEN 'yellow' THEN 2 WHEN 'blue' THEN 3 END) ASC
   LIMIT 1;

  IF v_next_slot IS NULL THEN
    SELECT slot INTO v_next_slot FROM public.ludo_participants
     WHERE game_id = _game_id AND forfeited = FALSE AND finish_rank IS NULL
     ORDER BY public._ludo_start_idx(CASE color WHEN 'red' THEN 0 WHEN 'green' THEN 1 WHEN 'yellow' THEN 2 WHEN 'blue' THEN 3 END) ASC
     LIMIT 1;
  END IF;

  RETURN COALESCE(v_next_slot, _from);
END $function$
;

CREATE OR REPLACE FUNCTION public._ludo_playable_pawns(_pawns jsonb, _slot integer, _dice integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  arr jsonb; pawn jsonb; i int; pstate text; pstep int;
  out jsonb := '[]'::jsonb;
BEGIN
  IF _dice IS NULL OR _slot IS NULL OR _pawns IS NULL THEN RETURN out; END IF;
  arr := _pawns -> _slot::text;
  IF arr IS NULL THEN RETURN out; END IF;
  FOR i IN 0..3 LOOP
    pawn := arr -> i;
    IF pawn IS NULL THEN CONTINUE; END IF;
    pstate := pawn->>'s';
    pstep  := COALESCE((pawn->>'k')::int, 0);
    IF pstate = 'finished' THEN CONTINUE; END IF;
    IF pstate = 'yard' THEN
      IF _dice = 6 THEN out := out || to_jsonb(i); END IF;
    ELSE
      IF pstep + _dice <= 56 THEN out := out || to_jsonb(i); END IF;
    END IF;
  END LOOP;
  RETURN out;
END $function$
;

CREATE OR REPLACE FUNCTION public._ludo_purge(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  DELETE FROM public.chat_rooms WHERE game_id = _game_id;
  DELETE FROM public.game_spectators WHERE game_id = _game_id;
  DELETE FROM public.game_invitations WHERE game_id = _game_id;
  DELETE FROM public.ludo_participants WHERE game_id = _game_id;
  DELETE FROM public.ludo_games WHERE id = _game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public._ludo_push_move(_game_id uuid, _entry jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE st jsonb; arr jsonb; len int;
BEGIN
  SELECT state INTO st FROM public.ludo_games WHERE id=_game_id;
  arr := COALESCE(st->'moves', '[]'::jsonb) || _entry;
  len := jsonb_array_length(arr);
  IF len > 20 THEN
    arr := (SELECT jsonb_agg(v) FROM (
      SELECT value AS v FROM jsonb_array_elements(arr) WITH ORDINALITY t(value, ord)
       ORDER BY ord OFFSET (len - 20)
    ) s);
  END IF;
  st := jsonb_set(st, '{moves}', arr);
  UPDATE public.ludo_games SET state=st WHERE id=_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public._ludo_set_ready_deadline()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE v_sec int;
BEGIN
  SELECT COALESCE(ready_timeout_seconds,60) INTO v_sec FROM public.app_settings WHERE id=1;
  NEW.ready_deadline := now() + (v_sec || ' seconds')::interval;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._ludo_start_for(_game_id uuid, _slot integer)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT CASE color
    WHEN 'red'    THEN 0
    WHEN 'green'  THEN 13
    WHEN 'yellow' THEN 26
    WHEN 'blue'   THEN 39
    ELSE 0
  END
  FROM public.ludo_participants
  WHERE game_id=_game_id AND slot=_slot;
$function$
;

CREATE OR REPLACE FUNCTION public._ludo_start_idx(_slot integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$ SELECT (ARRAY[0,13,26,39])[_slot+1] $function$
;

CREATE OR REPLACE FUNCTION public._ludo_sync_turn_snapshot()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  st jsonb; v_slot int; v_dice int; v_must boolean; v_playable jsonb;
BEGIN
  st := NEW.state;
  IF st IS NULL OR jsonb_typeof(st) <> 'object' THEN RETURN NEW; END IF;
  v_slot := NULLIF(st->>'turn_slot','')::int;
  v_dice := NULLIF(st->>'dice','null')::int;
  v_must := COALESCE((st->>'must_move')::boolean, false);
  IF v_must AND v_dice IS NOT NULL AND v_slot IS NOT NULL THEN
    v_playable := public._ludo_playable_pawns(st->'pawns', v_slot, v_dice);
  ELSE
    v_playable := '[]'::jsonb;
  END IF;
  st := jsonb_set(st, '{playable_pawns}', v_playable, true);
  IF v_slot IS NOT NULL THEN
    st := jsonb_set(st, '{turn_slot}', to_jsonb(v_slot), true);
    NEW.current_turn := v_slot;
  END IF;
  st := jsonb_set(st, '{dice}', COALESCE(to_jsonb(v_dice), 'null'::jsonb), true);
  NEW.state := st;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._mark_first_game()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE r record; v_table text := TG_ARGV[0];
BEGIN
  IF NEW.status = 'finished' AND (OLD.status IS NULL OR OLD.status <> 'finished') THEN
    IF v_table = 'chess' THEN
      IF NEW.white_id IS NOT NULL THEN
        UPDATE public.profiles SET first_game_at = COALESCE(first_game_at, now()) WHERE id = NEW.white_id;
        PERFORM public._try_unlock_referral(NEW.white_id);
      END IF;
      IF NEW.black_id IS NOT NULL THEN
        UPDATE public.profiles SET first_game_at = COALESCE(first_game_at, now()) WHERE id = NEW.black_id;
        PERFORM public._try_unlock_referral(NEW.black_id);
      END IF;
    ELSE
      FOR r IN EXECUTE format('SELECT DISTINCT user_id FROM public.%I_participants WHERE game_id = $1 AND user_id IS NOT NULL', v_table) USING NEW.id LOOP
        UPDATE public.profiles SET first_game_at = COALESCE(first_game_at, now()) WHERE id = r.user_id;
        PERFORM public._try_unlock_referral(r.user_id);
      END LOOP;
    END IF;
  END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._maybe_end_bot_only_domino(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.domino_games g SET status='finished', finished_at=now()
  WHERE g.id=_game_id AND g.status='playing'
    AND NOT EXISTS (SELECT 1 FROM public.domino_participants p WHERE p.game_id=g.id AND p.is_bot=false AND COALESCE(p.forfeited,false)=false);
END $function$
;

CREATE OR REPLACE FUNCTION public._maybe_end_bot_only_fanorona(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.fanorona_games g SET status='finished', finished_at=now()
  WHERE g.id=_game_id AND g.status='playing'
    AND NOT EXISTS (SELECT 1 FROM public.fanorona_participants p WHERE p.game_id=g.id AND p.is_bot=false AND COALESCE(p.forfeited,false)=false);
END $function$
;

CREATE OR REPLACE FUNCTION public._maybe_end_bot_only_ludo(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.ludo_games g SET status='finished', finished_at=now()
  WHERE g.id=_game_id AND g.status='playing' AND COALESCE(g.is_solo,false)=false
    AND NOT EXISTS (
      SELECT 1 FROM public.ludo_participants p
      WHERE p.game_id=g.id AND p.is_bot=false
        AND COALESCE(p.forfeited,false)=false
        AND p.finish_rank IS NULL
    );
END $function$
;

CREATE OR REPLACE FUNCTION public._maybe_end_bot_only_rami(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.rami_games g SET status='finished', finished_at=now()
  WHERE g.id=_game_id AND g.status='playing'
    AND NOT EXISTS (SELECT 1 FROM public.rami_participants p WHERE p.game_id=g.id AND p.is_bot=false AND COALESCE(p.forfeited,false)=false);
END $function$
;

CREATE OR REPLACE FUNCTION public._notify_deposit_created()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.status = 'pending' THEN
    INSERT INTO public.notifications(user_id, kind, title, body, link, ref_id)
    VALUES (NEW.user_id, 'deposit',
      'Dépôt en attente de validation',
      format('Votre dépôt de %s Ar a bien été reçu. En attente de vérification.', to_char(NEW.amount,'FM999G999G999')),
      '/history', NEW.id);
  END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._petanque_distance(ax double precision, ay double precision, bx double precision, by_ double precision)
 RETURNS double precision
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT sqrt((ax-bx)*(ax-bx) + (ay-by_)*(ay-by_));
$function$
;

CREATE OR REPLACE FUNCTION public._petanque_end_round(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  g public.petanque_games%ROWTYPE;
  v_best RECORD;
  v_pts INT := 0;
  v_new_x DOUBLE PRECISION;
  v_new_y DOUBLE PRECISION;
  v_starter_team INT;
  v_starter_uid UUID;
BEGIN
  SELECT * INTO g FROM public.petanque_games WHERE id=_game_id FOR UPDATE;
  -- Meilleure boule adverse fixe le seuil ; toutes les nôtres plus proches marquent
  SELECT team, distance INTO v_best FROM public.petanque_boules
    WHERE game_id=_game_id AND round=g.current_round AND dead=false
    ORDER BY distance ASC LIMIT 1;
  IF v_best IS NULL THEN
    -- Aucune boule : mène nulle, on continue
    v_starter_team := 0;
  ELSE
    -- Distance de la meilleure adverse
    DECLARE v_opp_best DOUBLE PRECISION;
    BEGIN
      SELECT min(distance) INTO v_opp_best FROM public.petanque_boules
        WHERE game_id=_game_id AND round=g.current_round AND dead=false AND team <> v_best.team;
      IF v_opp_best IS NULL THEN
        -- Adversaire n'a aucune boule valide : compte toutes les nôtres non mortes
        SELECT count(*) INTO v_pts FROM public.petanque_boules
          WHERE game_id=_game_id AND round=g.current_round AND dead=false AND team=v_best.team;
      ELSE
        SELECT count(*) INTO v_pts FROM public.petanque_boules
          WHERE game_id=_game_id AND round=g.current_round AND dead=false AND team=v_best.team
            AND distance < v_opp_best;
      END IF;
      IF v_best.team = 0 THEN
        UPDATE public.petanque_games SET score_team0 = score_team0 + v_pts WHERE id=_game_id;
      ELSE
        UPDATE public.petanque_games SET score_team1 = score_team1 + v_pts WHERE id=_game_id;
      END IF;
      v_starter_team := v_best.team;
    END;
  END IF;

  SELECT * INTO g FROM public.petanque_games WHERE id=_game_id;
  IF g.score_team0 >= g.target_points OR g.score_team1 >= g.target_points THEN
    UPDATE public.petanque_games
      SET status='finished', finished_at=now(),
          winner_team = CASE WHEN g.score_team0 >= g.target_points THEN 0 ELSE 1 END
      WHERE id=_game_id;
    PERFORM public._petanque_settle(_game_id);
    RETURN;
  END IF;

  -- Nouvelle mène
  v_new_x := 0.4 + random()*0.4; -- [0.4, 0.8]
  v_new_y := (random() - 0.5) * 0.3; -- [-0.15, 0.15]
  UPDATE public.petanque_games
    SET current_round = current_round + 1,
        cochonnet_x = v_new_x, cochonnet_y = v_new_y,
        turn_deadline = now() + interval '30 seconds'
    WHERE id=_game_id;
  UPDATE public.petanque_participants SET boules_left = 3 WHERE game_id=_game_id;
  -- L'équipe gagnante lance le cochonnet et la première boule
  SELECT user_id INTO v_starter_uid FROM public.petanque_participants
    WHERE game_id=_game_id AND team=v_starter_team ORDER BY seat LIMIT 1;
  UPDATE public.petanque_games SET current_player_id = v_starter_uid WHERE id=_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public._petanque_next_player(_game_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  g public.petanque_games%ROWTYPE;
  v_best_team INT;
  v_boules_t0 INT;
  v_boules_t1 INT;
  v_next_team INT;
  v_next_uid UUID;
  v_is_bot BOOLEAN;
BEGIN
  SELECT * INTO g FROM public.petanque_games WHERE id=_game_id;
  SELECT COALESCE(sum(boules_left),0) INTO v_boules_t0 FROM public.petanque_participants WHERE game_id=_game_id AND team=0;
  SELECT COALESCE(sum(boules_left),0) INTO v_boules_t1 FROM public.petanque_participants WHERE game_id=_game_id AND team=1;
  IF v_boules_t0 = 0 AND v_boules_t1 = 0 THEN RETURN NULL; END IF;
  IF v_boules_t0 = 0 THEN v_next_team := 1;
  ELSIF v_boules_t1 = 0 THEN v_next_team := 0;
  ELSE
    SELECT team INTO v_best_team FROM public.petanque_boules
      WHERE game_id=_game_id AND round=g.current_round AND dead=false
      ORDER BY distance ASC LIMIT 1;
    IF v_best_team IS NULL THEN v_next_team := 0;
    ELSE v_next_team := CASE WHEN v_best_team=0 THEN 1 ELSE 0 END; END IF;
  END IF;
  SELECT user_id, is_bot INTO v_next_uid, v_is_bot FROM public.petanque_participants
    WHERE game_id=_game_id AND team=v_next_team AND boules_left > 0 ORDER BY seat LIMIT 1;
  IF v_is_bot THEN RETURN NULL; END IF;
  RETURN v_next_uid;
END $function$
;

CREATE OR REPLACE FUNCTION public._petanque_settle(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  g public.petanque_games%ROWTYPE;
  v_pot NUMERIC;
  v_commission NUMERIC;
  v_gain NUMERIC;
  v_winner_uid UUID;
BEGIN
  SELECT * INTO g FROM public.petanque_games WHERE id=_game_id;
  IF g.winner_team IS NULL OR g.pot <= 0 THEN RETURN; END IF;
  v_pot := g.pot;
  v_commission := round(v_pot * 0.10);
  v_gain := v_pot - v_commission;
  SELECT user_id INTO v_winner_uid FROM public.petanque_participants
    WHERE game_id=_game_id AND team=g.winner_team AND is_bot=false ORDER BY seat LIMIT 1;
  IF v_winner_uid IS NOT NULL THEN
    UPDATE public.profiles SET balance_ar = balance_ar + v_gain WHERE id=v_winner_uid;
    INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
      VALUES (v_winner_uid,'win',v_gain,_game_id,'Gain pétanque');
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public._petanque_simulate(p_throw_y double precision, p_angle double precision, p_power double precision, p_spin double precision, p_lob double precision)
 RETURNS TABLE(final_x double precision, final_y double precision, dead boolean)
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  fly_dist    DOUBLE PRECISION;
  roll_dist   DOUBLE PRECISION;
  land_x      DOUBLE PRECISION;
  land_y      DOUBLE PRECISION;
  fx          DOUBLE PRECISION;
  fy          DOUBLE PRECISION;
BEGIN
  -- Clamp inputs
  p_power := GREATEST(0.05, LEAST(1.0, p_power));
  p_lob   := GREATEST(0.0, LEAST(1.0, p_lob));
  p_spin  := GREATEST(-1.0, LEAST(1.0, p_spin));
  -- Distance de vol (0.3 à 1.8 depuis x=-0.9)
  fly_dist  := 0.3 + p_power * 1.5;
  -- Roulage : quasi nul si lob=1, jusqu'à 0.35 si lob=0
  roll_dist := (1.0 - p_lob) * p_power * 0.35;
  land_x := -0.9 + cos(p_angle) * fly_dist;
  land_y := p_throw_y + sin(p_angle) * fly_dist;
  -- Après atterrissage : continue tout droit + drift latéral dû au spin
  fx := land_x + cos(p_angle) * roll_dist;
  fy := land_y + sin(p_angle) * roll_dist + p_spin * roll_dist * 0.6;
  -- Terrain : x ∈ [-1, 1.0], y ∈ [-0.45, 0.45]
  IF fx > 1.0 OR fx < -1.0 OR fy > 0.45 OR fy < -0.45 THEN
    RETURN QUERY SELECT fx, fy, true;
  ELSE
    RETURN QUERY SELECT fx, fy, false;
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public._poker_apply_turn_timer()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE v_secs int;
BEGIN
  -- Quand le serveur écrit un nouveau turn_deadline, on le recalcule
  -- à partir de app_settings.poker_turn_seconds (fallback turn_seconds, 30s).
  IF NEW.turn_deadline IS NOT NULL
     AND NEW.turn_deadline IS DISTINCT FROM COALESCE(OLD.turn_deadline, 'epoch'::timestamptz)
  THEN
    SELECT COALESCE(poker_turn_seconds, turn_seconds, 30) INTO v_secs
      FROM public.app_settings WHERE id = 1;
    NEW.turn_deadline := now() + (COALESCE(v_secs, 30) || ' seconds')::interval;
  END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._poker_award(_gid uuid, _winner uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g public.poker_games%ROWTYPE;
  gross numeric; net numeric; commission numeric;
  rake_pct numeric; rake_cap numeric;
  still_playing int;
  winner_is_bot boolean := false;
  hh_players jsonb := '[]'::jsonb;
  p RECORD;
BEGIN
  SELECT * INTO g FROM public.poker_games WHERE id=_gid FOR UPDATE;
  gross := g.pot;

  -- Rake: appliquer pct + cap depuis app_settings, avec fallback sur commission_pct
  SELECT COALESCE(poker_rake_pct, g.commission_pct), COALESCE(poker_rake_cap, 999999999)
    INTO rake_pct, rake_cap FROM public.app_settings WHERE id=1;
  IF g.tournament_id IS NOT NULL THEN
    -- Tournoi = pas de rake par main (déjà pris sur le buy-in)
    commission := 0;
  ELSE
    commission := LEAST(ROUND(gross * rake_pct / 100, 0), rake_cap);
  END IF;
  net := gross - commission;

  SELECT COALESCE(is_bot,false) INTO winner_is_bot
    FROM public.poker_players WHERE game_id=_gid AND user_id=_winner LIMIT 1;

  -- Snapshot des joueurs AVANT crédit
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'user_id', pp.user_id,
    'seat', pp.seat,
    'chips_before', pp.chips,
    'hole_cards', pp.hole_cards,
    'revealed', pp.status IN ('playing','all_in') AND (g.phase='showdown' OR _winner = pp.user_id),
    'is_bot', COALESCE(pp.is_bot,false),
    'name', COALESCE(pp.bot_name, (SELECT pseudo FROM public.profiles WHERE id=pp.user_id))
  )), '[]'::jsonb) INTO hh_players
  FROM public.poker_players pp WHERE pp.game_id=_gid;

  UPDATE public.poker_players SET chips=chips+net, status='finished' WHERE game_id=_gid AND user_id=_winner;
  UPDATE public.poker_players SET status='finished' WHERE game_id=_gid AND status='playing';

  -- Historique de la main
  INSERT INTO public.poker_hand_history(game_id, tournament_id, hand_number, pot, rake, board, winner_id, players)
  VALUES(_gid, g.tournament_id, g.hand_number, gross, commission, g.community_cards,
         CASE WHEN winner_is_bot THEN NULL ELSE _winner END, hh_players);

  -- Stats joueur (uniquement humains)
  FOR p IN SELECT user_id, COALESCE(is_bot,false) AS is_bot FROM public.poker_players WHERE game_id=_gid LOOP
    IF NOT p.is_bot THEN
      INSERT INTO public.player_game_stats(user_id, game_mode, hands_played, hands_won, showdowns_won, biggest_pot, total_winnings)
      VALUES(
        p.user_id, 'poker', 1,
        CASE WHEN p.user_id = _winner THEN 1 ELSE 0 END,
        CASE WHEN p.user_id = _winner AND g.phase='showdown' THEN 1 ELSE 0 END,
        CASE WHEN p.user_id = _winner THEN gross ELSE 0 END,
        CASE WHEN p.user_id = _winner THEN net ELSE 0 END
      )
      ON CONFLICT (user_id, game_mode) DO UPDATE SET
        hands_played  = player_game_stats.hands_played + 1,
        hands_won     = player_game_stats.hands_won + (CASE WHEN p.user_id = _winner THEN 1 ELSE 0 END),
        showdowns_won = player_game_stats.showdowns_won + (CASE WHEN p.user_id = _winner AND g.phase='showdown' THEN 1 ELSE 0 END),
        biggest_pot   = GREATEST(player_game_stats.biggest_pot, CASE WHEN p.user_id = _winner THEN gross ELSE 0 END),
        total_winnings= player_game_stats.total_winnings + (CASE WHEN p.user_id = _winner THEN net ELSE 0 END),
        updated_at    = now();
    END IF;
  END LOOP;

  SELECT count(*) INTO still_playing FROM public.poker_players
   WHERE game_id=_gid AND chips > 0 AND status NOT IN ('out','waiting');

  IF still_playing <= 1 THEN
    IF NOT winner_is_bot AND g.stake > 0 AND g.tournament_id IS NULL THEN
      UPDATE public.profiles SET balance_ar = balance_ar + net WHERE id = _winner;
      INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
      VALUES(_winner, 'win', net, _gid, 'Victoire Poker');
      IF commission > 0 THEN
        INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
        VALUES(_winner, 'stake', -commission, _gid, 'Commission Poker');
      END IF;
    END IF;

    UPDATE public.poker_players
      SET status='out', eliminated_at=COALESCE(eliminated_at, now())
      WHERE game_id=_gid AND chips <= 0;

    UPDATE public.poker_games SET
      status='finished', phase='finished',
      winner_id = CASE WHEN winner_is_bot THEN NULL ELSE _winner END,
      finished_at=now(), current_player=NULL, turn_deadline=NULL, updated_at=now()
    WHERE id=_gid;
  ELSE
    UPDATE public.poker_players SET status='playing', bet_round=0, hole_cards='{}', last_action=NULL
     WHERE game_id=_gid AND chips > 0;
    UPDATE public.poker_players
      SET status='out', eliminated_at=COALESCE(eliminated_at, now())
      WHERE game_id=_gid AND chips <= 0;
    UPDATE public.poker_games SET phase='between_hands', pot=0, community_cards='{}',
      current_player=NULL, turn_deadline=NULL, updated_at=now()
    WHERE id=_gid;
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._poker_bot_act(_gid uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g public.poker_games%ROWTYPE;
  bot public.poker_players%ROWTYPE;
  cur_bet numeric; call_amt numeric; min_raise_amt numeric; big_blind numeric;
  strength int; intel int; act text; raise_to numeric;
  n_active int; next_seat int; next_user uuid;
  rnd numeric;
BEGIN
  SELECT * INTO g FROM public.poker_games WHERE id=_gid FOR UPDATE;
  IF g.status != 'playing' OR g.current_player IS NULL THEN RETURN false; END IF;

  SELECT * INTO bot FROM public.poker_players
   WHERE game_id=_gid AND user_id = g.current_player;
  IF NOT FOUND OR NOT COALESCE(bot.is_bot,false) THEN RETURN false; END IF;

  cur_bet   := COALESCE((g.state->>'current_bet')::numeric, 0);
  big_blind := COALESCE((g.state->>'big_blind')::numeric, 100);
  call_amt  := GREATEST(cur_bet - bot.bet_round, 0);
  min_raise_amt := GREATEST(cur_bet * 2, cur_bet + COALESCE((g.state->>'last_raise')::numeric, big_blind));

  strength := public._poker_hand_strength(bot.hole_cards, g.community_cards);
  intel    := COALESCE(bot.bot_intelligence, 70);

  -- Bruit selon niveau : facile ± beaucoup, difficile ± peu
  rnd := (random() - 0.5) * (100 - intel) * 0.6;
  strength := GREATEST(0, LEAST(100, strength + rnd::int));

  -- Décision
  IF call_amt = 0 THEN
    -- Aucun coût pour checker
    IF strength >= 78 AND bot.chips >= min_raise_amt - bot.bet_round THEN
      act := 'bet';
      raise_to := LEAST(bot.chips + bot.bet_round,
                        GREATEST(min_raise_amt,
                                 bot.bet_round + big_blind * (CASE WHEN strength >= 90 THEN 5 ELSE 3 END)));
    ELSE
      act := 'check';
    END IF;
  ELSE
    -- Il faut suivre call_amt pour rester
    IF strength >= 88 AND bot.chips + bot.bet_round >= min_raise_amt THEN
      IF strength >= 95 AND random() < 0.4 THEN
        act := 'allin';
      ELSE
        act := 'raise';
        raise_to := LEAST(bot.chips + bot.bet_round,
                          GREATEST(min_raise_amt,
                                   cur_bet + big_blind * (CASE WHEN strength >= 92 THEN 4 ELSE 2 END)));
      END IF;
    ELSIF strength >= 45 THEN
      IF call_amt >= bot.chips THEN
        act := CASE WHEN strength >= 60 THEN 'allin' ELSE 'fold' END;
      ELSE
        act := 'call';
      END IF;
    ELSE
      -- Main faible
      IF call_amt <= big_blind AND strength >= 25 AND intel < 80 THEN
        act := 'call';   -- limp occasionnel des bots plus faibles
      ELSE
        act := 'fold';
      END IF;
    END IF;
  END IF;

  -- Applique l'action (copie condensée de poker_action, sans le check auth.uid)
  CASE act
    WHEN 'fold' THEN
      UPDATE public.poker_players SET status='folded', last_action='fold'
        WHERE id=bot.id;
    WHEN 'check' THEN
      UPDATE public.poker_players SET last_action='check' WHERE id=bot.id;
    WHEN 'call' THEN
      DECLARE actual numeric := LEAST(call_amt, bot.chips);
      BEGIN
        UPDATE public.poker_players SET chips=chips-actual, bet_round=bet_round+actual, last_action='call'
          WHERE id=bot.id;
        UPDATE public.poker_games SET pot=pot+actual, updated_at=now() WHERE id=_gid;
        IF bot.chips - actual <= 0 THEN
          UPDATE public.poker_players SET status='all_in' WHERE id=bot.id;
        END IF;
      END;
    WHEN 'bet','raise' THEN
      DECLARE add_chips numeric := GREATEST(0, raise_to - bot.bet_round);
      BEGIN
        UPDATE public.poker_players SET chips=chips-add_chips, bet_round=raise_to, last_action=act
          WHERE id=bot.id;
        UPDATE public.poker_games SET
          pot=pot+add_chips,
          state = state || jsonb_build_object('current_bet', raise_to, 'last_raise', raise_to - cur_bet),
          updated_at=now()
        WHERE id=_gid;
        IF bot.chips - add_chips <= 0 THEN
          UPDATE public.poker_players SET status='all_in' WHERE id=bot.id;
        END IF;
        UPDATE public.poker_players SET last_action=NULL
          WHERE game_id=_gid AND id != bot.id AND status='playing';
      END;
    WHEN 'allin' THEN
      DECLARE all_chips numeric := bot.chips;
      DECLARE new_total numeric := bot.bet_round + all_chips;
      BEGIN
        UPDATE public.poker_players SET chips=0, bet_round=new_total, status='all_in', last_action='allin'
          WHERE id=bot.id;
        UPDATE public.poker_games SET pot=pot+all_chips, updated_at=now() WHERE id=_gid;
        IF new_total > cur_bet THEN
          UPDATE public.poker_games SET state=state||jsonb_build_object('current_bet',new_total) WHERE id=_gid;
          UPDATE public.poker_players SET last_action=NULL
            WHERE game_id=_gid AND id != bot.id AND status='playing';
        END IF;
      END;
  END CASE;

  -- Après-coup : suite ou joueur suivant (même logique que poker_action)
  SELECT * INTO g FROM public.poker_games WHERE id=_gid;
  SELECT count(*) INTO n_active FROM public.poker_players
   WHERE game_id=_gid AND status='playing';

  IF n_active <= 1 OR public._poker_round_done(_gid) THEN
    PERFORM public._poker_next_street(_gid);
  ELSE
    next_seat := public._poker_next_player(_gid, bot.seat);
    SELECT user_id INTO next_user FROM public.poker_players
      WHERE game_id=_gid AND seat=next_seat;
    UPDATE public.poker_games
      SET current_player=next_user, turn_deadline=now()+interval '30 seconds', updated_at=now()
      WHERE id=_gid;
  END IF;

  RETURN true;
END $function$
;

CREATE OR REPLACE FUNCTION public._poker_hand_strength(hole integer[], community integer[])
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  r1 int; r2 int; s1 int; s2 int;
  hi int; lo int; strength int;
  sc bigint;
BEGIN
  IF hole IS NULL OR array_length(hole,1) < 2 THEN RETURN 0; END IF;
  r1 := public._poker_eval_rank(hole[1] % 13);
  r2 := public._poker_eval_rank(hole[2] % 13);
  s1 := hole[1] / 13;
  s2 := hole[2] / 13;
  hi := GREATEST(r1, r2);
  lo := LEAST(r1, r2);

  IF community IS NULL OR array_length(community,1) IS NULL OR array_length(community,1) = 0 THEN
    -- Préflop : heuristique simple
    IF r1 = r2 THEN
      RETURN LEAST(100, 40 + r1 * 4);      -- paire
    END IF;
    strength := hi * 3 + lo;
    IF s1 = s2 THEN strength := strength + 8; END IF;          -- assortis
    IF abs(r1 - r2) <= 2 THEN strength := strength + 4; END IF; -- connecteurs
    IF hi >= 12 THEN strength := strength + 10; END IF;         -- carte haute
    RETURN LEAST(100, strength);
  ELSE
    -- Postflop : basé sur le score de la meilleure main
    sc := public._poker_best_score(hole, community);
    IF sc >= 8000000000 THEN RETURN 100;
    ELSIF sc >= 7000000000 THEN RETURN 98;
    ELSIF sc >= 6000000000 THEN RETURN 92;
    ELSIF sc >= 5000000000 THEN RETURN 85;
    ELSIF sc >= 4000000000 THEN RETURN 78;
    ELSIF sc >= 3000000000 THEN RETURN 68;
    ELSIF sc >= 2000000000 THEN RETURN 55;
    ELSIF sc >= 1000000000 THEN RETURN 40;
    ELSE RETURN 15;
    END IF;
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public._prr_touch()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN NEW.updated_at = now(); RETURN NEW; END $function$
;

CREATE OR REPLACE FUNCTION public._rami_active_humans(_gid uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT count(*)::int FROM public.rami_participants
  WHERE game_id = _gid AND forfeited = false AND COALESCE(is_bot, false) = false
$function$
;

CREATE OR REPLACE FUNCTION public._rami_all_discards(_state jsonb)
 RETURNS integer[]
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE _m jsonb := public._rami_discards_map(_state);
  _k text; _acc int[] := ARRAY[]::int[]; _arr int[];
BEGIN
  FOR _k IN SELECT jsonb_object_keys(_m) LOOP
    _arr := ARRAY(SELECT jsonb_array_elements_text(_m->_k))::int[];
    _acc := _acc || _arr;
  END LOOP;
  RETURN _acc;
END $function$
;

CREATE OR REPLACE FUNCTION public._rami_autoplay_bots(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  g public.rami_games; part public.rami_participants; guard int := 0;
  _key text; _hand int[]; _card int; _deck int[]; _new_hand int[]; _hands jsonb;
  _melds jsonb; _melded int[]; _type text; _intel int; _parts int[]; _next int;
  _top int; _matched boolean;
  _cfg record;
  _state jsonb; _discards jsonb; _pile int[]; _last text; _reshuffle jsonb;
BEGIN
  LOOP
    guard := guard + 1;
    IF guard > 100 THEN EXIT; END IF;

    SELECT * INTO g FROM public.rami_games WHERE id = _game_id FOR UPDATE;
    IF NOT FOUND OR g.status <> 'playing' THEN EXIT; END IF;
    IF COALESCE(g.paused, false) THEN EXIT; END IF;

    SELECT * INTO part FROM public.rami_participants
     WHERE game_id = _game_id AND slot = g.current_turn AND forfeited = false;
    IF NOT FOUND OR NOT COALESCE(part.is_bot,false) THEN EXIT; END IF;

    _key   := COALESCE(part.user_id::text, 'bot:' || part.slot::text);
    _intel := COALESCE(part.bot_intelligence, 70);
    SELECT * INTO _cfg FROM public._game_cfg('rami');
    _state := public._rami_normalize_state(g.state);
    _discards := public._rami_discards_map(_state);
    _last := public._rami_last_discarder(_state);

    ------------------------------------------------------------
    -- DRAW PHASE
    ------------------------------------------------------------
    IF g.turn_phase = 'draw' THEN
      _deck    := COALESCE(ARRAY(SELECT jsonb_array_elements_text(_state->'deck'))::int[], ARRAY[]::int[]);
      _hand    := COALESCE(ARRAY(SELECT jsonb_array_elements_text(_state->'hands'->_key))::int[], ARRAY[]::int[]);
      _pile    := COALESCE(ARRAY(SELECT jsonb_array_elements_text(_discards->_last))::int[], ARRAY[]::int[]);
      _card    := NULL;
      _matched := false;

      IF _intel >= 70 AND array_length(_pile,1) IS NOT NULL AND array_length(_pile,1) > 0 THEN
        _top := _pile[array_length(_pile,1)];
        IF _top < 52 AND EXISTS (SELECT 1 FROM unnest(_hand) c WHERE c < 52 AND c%13 = _top%13) THEN
          _matched := true;
          _card := _top;
          _pile := _pile[1:array_length(_pile,1)-1];
          IF array_length(_pile,1) IS NULL THEN
            _discards := _discards - _last;
          ELSE
            _discards := jsonb_set(_discards, ARRAY[_last], to_jsonb(_pile));
          END IF;
        END IF;
      END IF;

      IF NOT _matched THEN
        IF array_length(_deck,1) IS NULL THEN
          _reshuffle := public._rami_reshuffle(_state);
          _deck := COALESCE(ARRAY(SELECT jsonb_array_elements_text(_reshuffle->'deck'))::int[], ARRAY[]::int[]);
          _discards := _reshuffle->'discards';
          IF array_length(_deck,1) IS NULL THEN EXIT; END IF;
        END IF;
        _card := _deck[1];
        _deck := _deck[2:array_length(_deck,1)];
      END IF;

      _hand := array_append(_hand, _card);
      _hands := jsonb_set(_state->'hands', ARRAY[_key], to_jsonb(_hand));
      _state := jsonb_set(_state,'{deck}',to_jsonb(_deck));
      _state := jsonb_set(_state,'{discards}',_discards);
      _state := jsonb_set(_state,'{hands}',_hands);
      _state := _state - 'discard';

      UPDATE public.rami_games
         SET state = _state,
             turn_phase = 'play',
             updated_at = now()
       WHERE id = _game_id;
      UPDATE public.rami_participants
         SET hand_count = COALESCE(array_length(_hand,1),0)
       WHERE game_id = _game_id AND slot = part.slot;
      CONTINUE;
    END IF;

    ------------------------------------------------------------
    -- PLAY PHASE
    ------------------------------------------------------------
    _hand  := COALESCE(ARRAY(SELECT jsonb_array_elements_text(_state->'hands'->_key))::int[], ARRAY[]::int[]);
    _melds := COALESCE(_state->'melds','[]'::jsonb);

    IF _intel >= 50 AND COALESCE(array_length(_hand,1),0) >= 4 THEN
      SELECT ARRAY[_hand[i], _hand[j], _hand[k]] INTO _melded
        FROM generate_subscripts(_hand,1) i, generate_subscripts(_hand,1) j, generate_subscripts(_hand,1) k
       WHERE i < j AND j < k
         AND public._rami_meld_type(ARRAY[_hand[i],_hand[j],_hand[k]], g.joker_mode, g.random_joker) IS NOT NULL
       LIMIT 1;

      IF _melded IS NOT NULL THEN
        _type := public._rami_meld_type(_melded, g.joker_mode, g.random_joker);
        _new_hand := _hand;
        FOREACH _card IN ARRAY _melded LOOP
          _new_hand := public._rami_remove_one(_new_hand, _card);
        END LOOP;
        _melds := _melds || jsonb_build_array(jsonb_build_object(
          'player', _key,
          'cards',  to_jsonb(_melded),
          'type',   _type
        ));
        _hands := jsonb_set(_state->'hands', ARRAY[_key], to_jsonb(_new_hand));
        _state := jsonb_set(_state,'{hands}',_hands);
        _state := jsonb_set(_state,'{melds}',_melds);
        UPDATE public.rami_games SET state=_state, updated_at=now() WHERE id=_game_id;
        UPDATE public.rami_participants SET hand_count=COALESCE(array_length(_new_hand,1),0)
          WHERE game_id=_game_id AND slot=part.slot;
        _melded := NULL;
        CONTINUE;
      END IF;
    END IF;

    IF COALESCE(array_length(_hand,1),0) = 0 THEN EXIT; END IF;

    IF _intel < 50 THEN
      _card := _hand[1 + floor(random() * array_length(_hand,1))::int];
    ELSE
      SELECT c INTO _card FROM unnest(_hand) c
        ORDER BY (CASE WHEN c < 52 THEN c%13 ELSE -1 END) DESC, random()
        LIMIT 1;
    END IF;

    _new_hand := public._rami_remove_one(_hand, _card);
    _pile := COALESCE(ARRAY(SELECT jsonb_array_elements_text(_discards->_key))::int[], ARRAY[]::int[]);
    _pile := array_append(_pile, _card);
    _discards := jsonb_set(_discards, ARRAY[_key], to_jsonb(_pile), true);
    _hands := jsonb_set(_state->'hands', ARRAY[_key], to_jsonb(_new_hand));

    IF COALESCE(array_length(_new_hand,1),0) = 0 THEN
      _state := jsonb_set(_state,'{hands}',_hands);
      _state := jsonb_set(_state,'{discards}',_discards);
      _state := jsonb_set(_state,'{last_discard_by}',to_jsonb(_key));
      _state := _state - 'discard';
      IF public._rami_check_win(_state, _key) THEN
        UPDATE public.rami_games
           SET status='finished', winner_id=part.user_id, finished_at=now(), state=_state
         WHERE id=_game_id;
        UPDATE public.rami_participants SET hand_count=0
         WHERE game_id=_game_id AND slot=part.slot;
        EXIT;
      ELSE
        _card := _hand[1 + floor(random() * array_length(_hand,1))::int];
        _new_hand := public._rami_remove_one(_hand, _card);
        _pile := COALESCE(ARRAY(SELECT jsonb_array_elements_text(g.state->'discards'->_key))::int[], ARRAY[]::int[]);
        _pile := array_append(_pile, _card);
        _discards := public._rami_discards_map(g.state);
        _discards := jsonb_set(_discards, ARRAY[_key], to_jsonb(_pile), true);
        _hands := jsonb_set(g.state->'hands', ARRAY[_key], to_jsonb(_new_hand));
      END IF;
    END IF;

    SELECT array_agg(slot ORDER BY slot) INTO _parts
      FROM public.rami_participants WHERE game_id = _game_id AND NOT forfeited;
    _next := g.current_turn;
    LOOP
      _next := (_next + 1) % g.max_players;
      EXIT WHEN _next = ANY(_parts);
    END LOOP;

    _state := jsonb_set(_state,'{hands}',_hands);
    _state := jsonb_set(_state,'{discards}',_discards);
    _state := jsonb_set(_state,'{last_discard_by}',to_jsonb(_key));
    _state := _state - 'discard';

    UPDATE public.rami_games
       SET state = _state,
           current_turn = _next,
           turn_phase = 'draw',
           turn_deadline = now() + (_cfg.turn_timer_seconds || ' seconds')::interval,
           updated_at = now()
     WHERE id = _game_id;
    UPDATE public.rami_participants
       SET hand_count = COALESCE(array_length(_new_hand,1),0)
     WHERE game_id = _game_id AND slot = part.slot;
  END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION public._rami_check_win(_state jsonb, _uid uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE _carre int := 0; _trio int := 0; _run int := 0; _total int := 0;
  _m jsonb; _t text; _cards int[]; _n int;
BEGIN
  FOR _m IN SELECT * FROM jsonb_array_elements(COALESCE(_state->'melds','[]'::jsonb)) LOOP
    IF _m->>'player' = _uid::text THEN
      _t := _m->>'type';
      _cards := ARRAY(SELECT jsonb_array_elements_text(_m->'cards'))::int[];
      _n := COALESCE(array_length(_cards,1),0);
      _total := _total + _n;
      IF _t = 'carre' THEN _carre := _carre + 1;
      ELSIF _t = 'trio' THEN _trio := _trio + 1;
      ELSIF _t = 'run' THEN _run := _run + 1;
      END IF;
    END IF;
  END LOOP;
  RETURN _carre >= 1 AND _trio >= 2 AND _run >= 1 AND _total >= 13;
END $function$
;

CREATE OR REPLACE FUNCTION public._rami_check_win(_state jsonb, _key text)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE _carre int := 0; _trio int := 0; _run int := 0; _total int := 0;
  _m jsonb; _t text; _cards int[]; _n int;
BEGIN
  FOR _m IN SELECT * FROM jsonb_array_elements(COALESCE(_state->'melds','[]'::jsonb)) LOOP
    IF _m->>'player' = _key THEN
      _t := _m->>'type';
      _cards := ARRAY(SELECT jsonb_array_elements_text(_m->'cards'))::int[];
      _n := COALESCE(array_length(_cards,1),0);
      _total := _total + _n;
      IF _t = 'carre' THEN _carre := _carre + 1;
      ELSIF _t = 'trio' THEN _trio := _trio + 1;
      ELSIF _t = 'run'  THEN _run  := _run  + 1;
      END IF;
    END IF;
  END LOOP;
  RETURN _carre >= 1 AND _trio >= 2 AND _run >= 1 AND _total >= 13;
END $function$
;

CREATE OR REPLACE FUNCTION public._rami_discards_map(_state jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE _m jsonb;
BEGIN
  _m := _state->'discards';
  IF _m IS NULL OR jsonb_typeof(_m) <> 'object' THEN
    IF _state ? 'discard' AND jsonb_array_length(COALESCE(_state->'discard','[]'::jsonb)) > 0 THEN
      RETURN jsonb_build_object('_seed', _state->'discard');
    END IF;
    RETURN '{}'::jsonb;
  END IF;
  RETURN _m;
END $function$
;

CREATE OR REPLACE FUNCTION public._rami_gen_code()
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE c text; BEGIN
  LOOP
    c := upper(substr(md5(random()::text||clock_timestamp()::text),1,6));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.rami_games WHERE room_code = c);
  END LOOP;
  RETURN c;
END $function$
;

CREATE OR REPLACE FUNCTION public._rami_is_joker(_c integer, _mode text, _rj integer)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE _rd int; _sd int; _r int; _s int; _color_d int; _color int;
BEGIN
  IF _c IS NULL THEN RETURN false; END IF;
  IF _c >= 52 AND _mode IN ('classique','double') THEN RETURN true; END IF;
  IF _mode IN ('aleatoire','double') AND _rj IS NOT NULL AND _c < 52 AND _rj < 52 THEN
    _rd := _rj % 13; _sd := _rj / 13;
    _r  := _c  % 13; _s  := _c  / 13;
    IF _r = _rd AND _s <> _sd THEN
      _color_d := CASE WHEN _sd IN (0,3) THEN 0 ELSE 1 END; -- 0 = noir, 1 = rouge
      _color   := CASE WHEN _s  IN (0,3) THEN 0 ELSE 1 END;
      IF _color <> _color_d THEN RETURN true; END IF; -- Vrai Joker = couleur opposée
    END IF;
  END IF;
  RETURN false;
END $function$
;

CREATE OR REPLACE FUNCTION public._rami_last_discarder(_state jsonb)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT COALESCE(_state->>'last_discard_by', '_seed')
$function$
;

CREATE OR REPLACE FUNCTION public._rami_meld_type(_cards integer[], _mode text, _rj integer)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  _n int := COALESCE(array_length(_cards,1),0);
  _c int; _jokers int := 0; _reals int := 0;
  _rank int := -1; _suit int := -1; _r int; _s int;
  _ranks int[] := ARRAY[]::int[];
  _is_set boolean := true; _is_run boolean := true;
  _try_high int; _base int; _ok boolean; _used boolean[]; _idx int;
BEGIN
  IF _n < 3 THEN RETURN NULL; END IF;
  FOREACH _c IN ARRAY _cards LOOP
    IF _c < 0 THEN RETURN NULL; END IF;
    IF public._rami_is_joker(_c,_mode,_rj) THEN
      _jokers := _jokers + 1;
    ELSE
      IF _c >= 52 THEN RETURN NULL; END IF; -- classique joker non actif dans ce mode
      _reals := _reals + 1;
      _r := _c % 13; _s := _c / 13;
      IF _rank = -1 THEN _rank := _r; ELSIF _rank <> _r THEN _is_set := false; END IF;
      IF _suit = -1 THEN _suit := _s; ELSIF _suit <> _s THEN _is_run := false; END IF;
      _ranks := _ranks || _r;
    END IF;
  END LOOP;
  IF _reals < 2 THEN RETURN NULL; END IF;
  IF _jokers > _reals THEN RETURN NULL; END IF;

  -- TRIO / CARRE
  IF _is_set AND _n IN (3,4) THEN
    IF _n = 4 THEN RETURN 'carre'; ELSE RETURN 'trio'; END IF;
  END IF;

  -- ESCALIER
  IF _is_run THEN
    FOR _try_high IN 0..1 LOOP
      DECLARE _rs int[] := _ranks; _i int; BEGIN
        IF _try_high = 1 THEN
          FOR _i IN 1..array_length(_rs,1) LOOP
            IF _rs[_i] = 0 THEN _rs[_i] := 13; END IF;
          END LOOP;
        END IF;
        -- distinct ranks
        IF (SELECT count(*) FROM (SELECT DISTINCT unnest(_rs)) x) <> array_length(_rs,1) THEN
          CONTINUE;
        END IF;
        FOR _base IN GREATEST(0,(SELECT min(x) FROM unnest(_rs) x) - _jokers)
                  .. LEAST(13 - _n + 1, (SELECT min(x) FROM unnest(_rs) x)) LOOP
          _used := array_fill(false, ARRAY[_n]); _ok := true;
          FOR _i IN 1..array_length(_rs,1) LOOP
            _idx := _rs[_i] - _base + 1;
            IF _idx < 1 OR _idx > _n OR _used[_idx] THEN _ok := false; EXIT; END IF;
            _used[_idx] := true;
          END LOOP;
          IF _ok THEN RETURN 'run'; END IF;
        END LOOP;
      END;
    END LOOP;
  END IF;
  RETURN NULL;
END $function$
;

CREATE OR REPLACE FUNCTION public._rami_normalize_state(_state jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE _s jsonb := _state;
BEGIN
  IF _s IS NULL THEN RETURN _s; END IF;
  IF NOT (_s ? 'discards') THEN
    _s := jsonb_set(_s, '{discards}', public._rami_discards_map(_state), true);
  END IF;
  IF NOT (_s ? 'last_discard_by') THEN
    _s := jsonb_set(_s, '{last_discard_by}', to_jsonb(public._rami_last_discarder(_state)), true);
  END IF;
  -- keep old 'discard' field for any legacy reader, but sync it to combined top view (removed on next write)
  RETURN _s;
END $function$
;

CREATE OR REPLACE FUNCTION public._rami_remove_one(_arr integer[], _v integer)
 RETURNS integer[]
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE i int; out int[] := ARRAY[]::int[]; removed boolean := false;
BEGIN
  IF _arr IS NULL THEN RETURN ARRAY[]::int[]; END IF;
  FOR i IN 1..array_length(_arr,1) LOOP
    IF NOT removed AND _arr[i] = _v THEN removed := true;
    ELSE out := array_append(out, _arr[i]);
    END IF;
  END LOOP;
  RETURN out;
END $function$
;

CREATE OR REPLACE FUNCTION public._rami_reshuffle(_state jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  _m jsonb := public._rami_discards_map(_state);
  _last text := public._rami_last_discarder(_state);
  _top_pile int[] := COALESCE(ARRAY(SELECT jsonb_array_elements_text(_m->_last))::int[], ARRAY[]::int[]);
  _keep int; _pool int[] := ARRAY[]::int[]; _k text; _arr int[]; _new_deck int[]; _new_map jsonb;
BEGIN
  IF array_length(_top_pile,1) IS NULL THEN
    RETURN jsonb_build_object('deck','[]'::jsonb,'discards','{}'::jsonb,'last', _last);
  END IF;
  _keep := _top_pile[array_length(_top_pile,1)];
  FOR _k IN SELECT jsonb_object_keys(_m) LOOP
    _arr := ARRAY(SELECT jsonb_array_elements_text(_m->_k))::int[];
    IF _k = _last THEN
      _arr := _arr[1:array_length(_arr,1)-1];
    END IF;
    IF array_length(_arr,1) IS NOT NULL THEN
      _pool := _pool || _arr;
    END IF;
  END LOOP;
  _new_deck := (SELECT array_agg(c ORDER BY random()) FROM unnest(_pool) c);
  _new_map := jsonb_build_object(_last, jsonb_build_array(_keep));
  RETURN jsonb_build_object(
    'deck', COALESCE(to_jsonb(_new_deck), '[]'::jsonb),
    'discards', _new_map,
    'last', _last
  );
END $function$
;

CREATE OR REPLACE FUNCTION public._rami_validate_meld(_cards integer[])
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  n int; jokers int := 0; non_jokers int[] := ARRAY[]::int[];
  suits int[] := ARRAY[]::int[]; ranks int[] := ARRAY[]::int[];
  c int; min_r int; max_r int; span int; nj int;
BEGIN
  n := COALESCE(array_length(_cards,1),0);
  IF n < 3 OR n > 14 THEN RETURN false; END IF;
  FOREACH c IN ARRAY _cards LOOP
    IF c < 0 OR c > 53 THEN RETURN false; END IF;
    IF c >= 52 THEN jokers := jokers + 1;
    ELSE
      non_jokers := array_append(non_jokers, c);
      suits := array_append(suits, c/13);
      ranks := array_append(ranks, c%13);
    END IF;
  END LOOP;
  nj := COALESCE(array_length(non_jokers,1),0);
  IF nj = 0 THEN RETURN false; END IF;
  -- SET
  IF n <= 4
    AND (SELECT count(DISTINCT x) FROM unnest(ranks) x) = 1
    AND (SELECT count(DISTINCT x) FROM unnest(suits) x) = nj
  THEN RETURN true; END IF;
  -- RUN
  IF (SELECT count(DISTINCT x) FROM unnest(suits) x) = 1
    AND (SELECT count(DISTINCT x) FROM unnest(ranks) x) = nj
  THEN
    SELECT min(x), max(x) INTO min_r, max_r FROM unnest(ranks) x;
    span := max_r - min_r + 1;
    IF span <= n AND n <= 13 AND jokers >= (span - nj) THEN RETURN true; END IF;
  END IF;
  RETURN false;
END $function$
;

CREATE OR REPLACE FUNCTION public._rami_visible(_game_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS(
    SELECT 1 FROM public.rami_games g
    WHERE g.id = _game_id
      AND (
        (g.status IN ('open','playing') AND g.is_private = false)
        OR g.created_by = auth.uid()
        OR EXISTS(SELECT 1 FROM public.rami_participants p WHERE p.game_id = g.id AND p.user_id = auth.uid())
        OR public.is_admin()
      )
  )
$function$
;

CREATE OR REPLACE FUNCTION public._referral_on_deposit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_parent uuid;
  v_cfg    public.referral_settings%ROWTYPE;
BEGIN
  IF NEW.status <> 'approved' THEN RETURN NEW; END IF;
  IF OLD.status = 'approved' THEN RETURN NEW; END IF;
  SELECT referred_by INTO v_parent FROM public.profiles WHERE id = NEW.user_id;
  IF v_parent IS NULL OR v_parent = NEW.user_id THEN RETURN NEW; END IF;
  SELECT * INTO v_cfg FROM public.referral_settings WHERE id = 1;
  IF NOT v_cfg.enabled THEN RETURN NEW; END IF;
  UPDATE public.profiles
     SET first_deposit_at = COALESCE(first_deposit_at, now()),
         first_deposit_amount = COALESCE(first_deposit_amount, NEW.amount)
   WHERE id = NEW.user_id;
  INSERT INTO public.referral_events(referrer_id, referee_id, event_type, reward_amount, note)
  VALUES(v_parent, NEW.user_id, 'first_deposit', 0,
         format('1er dépôt %s Ar — aucun bonus (règle: commission sur mise uniquement)', to_char(NEW.amount, 'FM999G999G999')))
  ON CONFLICT (referee_id, event_type) DO NOTHING;
  RETURN NEW;
END;
$function$
;

-- ═══════════ 0007_functions_04.sql ═══════════
-- 0007_functions_04.sql
-- Fonctions et procédures (4/12)

CREATE OR REPLACE FUNCTION public._referral_on_phone_verified()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.phone_verified = true AND (OLD.phone_verified IS DISTINCT FROM true) THEN
    PERFORM public._try_unlock_referral(NEW.id);
  END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._referral_on_signup()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.referred_by IS NOT NULL THEN
    INSERT INTO public.referral_events(referrer_id, referee_id, event_type, reward_amount, note)
    VALUES(NEW.referred_by, NEW.id, 'signup', 0, 'Inscription avec code parrain')
    ON CONFLICT(referee_id, event_type) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._referral_on_stake()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_stake       numeric;
  v_parent      uuid;
  v_count       integer;
  v_cfg         public.referral_settings%ROWTYPE;
  v_reward      numeric;
  v_pseudo      text;
  v_referee_bot boolean;
  v_referee_ban boolean;
  v_parent_bot  boolean;
  v_parent_ban  boolean;
  v_admin_ref   boolean;
BEGIN
  IF NEW.type NOT IN (
    'chess_stake','ludo_stake','domino_stake','fanorona_stake',
    'rami_stake','petanque_stake','poker_stake','billiard_stake'
  ) THEN RETURN NEW; END IF;

  v_stake := ABS(COALESCE(NEW.amount, 0));
  IF v_stake <= 0 THEN RETURN NEW; END IF;

  SELECT * INTO v_cfg FROM public.referral_settings WHERE id = 1;
  IF NOT v_cfg.enabled THEN RETURN NEW; END IF;
  IF COALESCE(v_cfg.stake_commission_pct, 0) <= 0 THEN RETURN NEW; END IF;
  IF COALESCE(v_cfg.stake_commission_max_matches, 0) <= 0 THEN RETURN NEW; END IF;

  SELECT referred_by, referral_stake_count,
         COALESCE(is_bot,false), COALESCE(is_banned,false)
    INTO v_parent, v_count, v_referee_bot, v_referee_ban
    FROM public.profiles WHERE id = NEW.user_id;

  IF v_parent IS NULL OR v_parent = NEW.user_id THEN RETURN NEW; END IF;
  IF v_referee_bot OR v_referee_ban THEN RETURN NEW; END IF;

  SELECT COALESCE(is_bot,false), COALESCE(is_banned,false)
    INTO v_parent_bot, v_parent_ban
    FROM public.profiles WHERE id = v_parent;
  IF v_parent_bot OR v_parent_ban THEN RETURN NEW; END IF;

  SELECT public.has_role(v_parent, 'admin'::public.app_role) INTO v_admin_ref;
  IF v_admin_ref THEN RETURN NEW; END IF;

  IF COALESCE(v_count,0) >= v_cfg.stake_commission_max_matches THEN RETURN NEW; END IF;

  v_reward := ROUND(v_stake * (v_cfg.stake_commission_pct / 100.0), 0);
  IF v_reward <= 0 THEN RETURN NEW; END IF;

  UPDATE public.profiles
     SET referral_stake_count = COALESCE(referral_stake_count,0) + 1
   WHERE id = NEW.user_id
   RETURNING referral_stake_count INTO v_count;

  UPDATE public.profiles SET balance_ar = balance_ar + v_reward WHERE id = v_parent;

  SELECT pseudo INTO v_pseudo FROM public.profiles WHERE id = NEW.user_id;

  BEGIN
    INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
    VALUES(v_parent, 'referral', v_reward, NEW.id,
      format('Parrainage %s — %s%% de %.0f Ar (partie %s/%s)',
             COALESCE(v_pseudo,'filleul'), v_cfg.stake_commission_pct,
             v_stake, v_count, v_cfg.stake_commission_max_matches));
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    INSERT INTO public.referral_events(referrer_id, referee_id, event_type, reward_amount, note)
    VALUES(v_parent, NEW.user_id, 'stake_' || v_count::text, v_reward,
      format('%s%% × %.0f Ar (partie %s/%s)',
             v_cfg.stake_commission_pct, v_stake,
             v_count, v_cfg.stake_commission_max_matches));
  EXCEPTION WHEN OTHERS THEN NULL; END;

  BEGIN
    INSERT INTO public.notifications(user_id, kind, title, body, link)
    VALUES(v_parent, 'referral', 'Commission parrainage 💰',
      format('+%s Ar : %s a joué (partie %s/%s).',
        to_char(v_reward,'FM999G999G999'),
        COALESCE(v_pseudo,'filleul'), v_count, v_cfg.stake_commission_max_matches),
      '/parrainage');
  EXCEPTION WHEN OTHERS THEN NULL; END;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._set_chess_global_deadline()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  enabled boolean;
  mins integer;
BEGIN
  IF NEW.status = 'playing' AND (OLD.status IS DISTINCT FROM 'playing') AND NEW.game_deadline IS NULL THEN
    SELECT chess_global_timer_enabled, chess_global_timer_minutes INTO enabled, mins FROM public.app_settings WHERE id = 1;
    IF COALESCE(enabled, false) AND COALESCE(mins, 0) > 0 THEN
      NEW.game_deadline := now() + (mins || ' minutes')::interval;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._set_fanorona_global_deadline()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  enabled boolean;
  mins integer;
BEGIN
  IF NEW.status = 'playing' AND (OLD.status IS DISTINCT FROM 'playing') AND NEW.game_deadline IS NULL THEN
    SELECT fanorona_global_timer_enabled, fanorona_global_timer_minutes INTO enabled, mins FROM public.app_settings WHERE id = 1;
    IF COALESCE(enabled, false) AND COALESCE(mins, 0) > 0 THEN
      NEW.game_deadline := now() + (mins || ' minutes')::interval;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._set_turn_deadline()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.status = 'playing' AND (TG_OP = 'INSERT' OR OLD.status <> 'playing' OR OLD.current_turn IS DISTINCT FROM NEW.current_turn) THEN
    NEW.turn_deadline := now() + interval '30 seconds';
  ELSIF NEW.status <> 'playing' THEN
    NEW.turn_deadline := NULL;
  END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._skip_noop_update()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW IS NOT DISTINCT FROM OLD THEN
    RETURN NULL;  -- annule l'UPDATE, aucun write, aucun événement realtime
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._sync_banned_flags()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF TG_OP IN ('INSERT','UPDATE') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='profiles' AND column_name='banned') THEN
      IF NEW.is_banned IS DISTINCT FROM COALESCE(NEW.banned, false) THEN
        IF TG_OP='INSERT' OR NEW.is_banned IS DISTINCT FROM OLD.is_banned THEN
          NEW.banned := NEW.is_banned;
        ELSIF NEW.banned IS DISTINCT FROM OLD.banned THEN
          NEW.is_banned := COALESCE(NEW.banned, false);
        END IF;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._t_build_round(_tid uuid, _round integer, _ids uuid[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE t public.tournaments%ROWTYPE; n int; i int := 1; v_take int; v_rest int; v_mno int := 0;
BEGIN
  SELECT * INTO t FROM public.tournaments WHERE id = _tid;
  n := COALESCE(array_length(_ids,1),0);
  IF n = 0 THEN RETURN; END IF;

  IF n = 1 THEN
    UPDATE public.tournaments SET champion_entrant_id = _ids[1] WHERE id = _tid;
    PERFORM public._t_finish(_tid);
    RETURN;
  END IF;

  WHILE i <= n LOOP
    v_rest := n - i + 1;
    v_take := LEAST(2, v_rest);
    -- joueur seul restant : table de 3 en Ludo, sinon il est qualifié d'office
    IF v_rest = 3 THEN
      IF t.game_slug = 'ludo' THEN
        v_take := 3;
      ELSE
        v_take := 2;
      END IF;
    END IF;
    IF v_rest = 1 THEN
      -- impossible d'appairer : le joueur passe directement au tour suivant
      EXIT;
    END IF;
    v_mno := v_mno + 1;
    INSERT INTO public.tournament_matches(tournament_id, phase, round, match_no, entrant_ids)
      VALUES (_tid, 'final', _round, v_mno, (SELECT array_agg(_ids[j]) FROM generate_series(i, i + v_take - 1) j));
    i := i + v_take;
  END LOOP;

  UPDATE public.tournaments SET stage = 'finals', current_round = _round WHERE id = _tid;
END $function$
;

CREATE OR REPLACE FUNCTION public._t_draw_pools(_tid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  t public.tournaments%ROWTYPE;
  ids uuid[]; pids uuid[];
  n int; pos int := 1; k int := 0; v_take int; v_rest int; v_pool uuid;
  a int; b int; v_mno int;
BEGIN
  SELECT * INTO t FROM public.tournaments WHERE id = _tid;
  SELECT array_agg(id ORDER BY random()) INTO ids
    FROM public.tournament_entrants WHERE tournament_id = _tid AND status = 'active';
  n := COALESCE(array_length(ids, 1), 0);
  IF n < 2 THEN RETURN; END IF;

  WHILE pos <= n LOOP
    v_rest := n - pos + 1;
    v_take := LEAST(t.pool_size, v_rest);
    IF v_rest - v_take = 1 THEN v_take := v_take + 1; END IF;
    v_take := LEAST(v_take, v_rest);
    pids := ids[pos : pos + v_take - 1];

    k := k + 1;
    INSERT INTO public.tournament_pools(tournament_id, label, status)
      VALUES (_tid, 'Poule ' || chr(64 + k), 'running') RETURNING id INTO v_pool;

    INSERT INTO public.tournament_pool_entrants(pool_id, entrant_id)
      SELECT v_pool, unnest(pids);

    IF t.players_per_match = 2 THEN
      v_mno := 0;
      FOR a IN 1 .. v_take - 1 LOOP
        FOR b IN a + 1 .. v_take LOOP
          v_mno := v_mno + 1;
          INSERT INTO public.tournament_matches(tournament_id, pool_id, phase, round, match_no, entrant_ids)
            VALUES (_tid, v_pool, 'pool', 1, v_mno, ARRAY[pids[a], pids[b]]);
        END LOOP;
      END LOOP;
    ELSE
      INSERT INTO public.tournament_matches(tournament_id, pool_id, phase, round, match_no, entrant_ids)
        VALUES (_tid, v_pool, 'pool', 1, k, pids);
    END IF;

    pos := pos + v_take;
  END LOOP;

  UPDATE public.tournaments SET stage = 'pools', current_round = 1 WHERE id = _tid;
END $function$
;

CREATE OR REPLACE FUNCTION public._t_finish(_tid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  t public.tournaments%ROWTYPE; v_net numeric; v_pcts numeric[]; r record; i int; v_amt numeric;
  v_final_loser uuid; v_tp_win uuid; v_tp_lose uuid;
BEGIN
  SELECT * INTO t FROM public.tournaments WHERE id = _tid FOR UPDATE;
  IF t.status IN ('finished','cancelled') THEN RETURN; END IF;

  -- finaliste (perdant du dernier match 'final')
  SELECT x.eid INTO v_final_loser FROM (
    SELECT unnest(m.entrant_ids) eid, m.winner_entrant_id w, m.round
      FROM public.tournament_matches m
     WHERE m.tournament_id = _tid AND m.phase = 'final' AND m.status = 'finished'
       AND t.champion_entrant_id = ANY(m.entrant_ids)
     ORDER BY m.round DESC LIMIT 4) x
   WHERE x.eid IS DISTINCT FROM t.champion_entrant_id LIMIT 1;

  SELECT m.winner_entrant_id INTO v_tp_win FROM public.tournament_matches m
   WHERE m.tournament_id = _tid AND m.phase = 'third_place' AND m.status = 'finished' LIMIT 1;
  IF v_tp_win IS NOT NULL THEN
    SELECT x.eid INTO v_tp_lose FROM (
      SELECT unnest(m.entrant_ids) eid FROM public.tournament_matches m
       WHERE m.tournament_id = _tid AND m.phase = 'third_place' AND m.status = 'finished') x
     WHERE x.eid IS DISTINCT FROM v_tp_win LIMIT 1;
  END IF;

  WITH keyed AS (
    SELECT e.id,
           CASE
             WHEN e.id = t.champion_entrant_id THEN 0
             WHEN e.id = v_final_loser THEN 1
             WHEN e.id = v_tp_win THEN 2
             WHEN e.id = v_tp_lose THEN 3
             ELSE 10
           END AS k,
           e.eliminated_round, e.created_at
      FROM public.tournament_entrants e WHERE e.tournament_id = _tid
  ), ranked AS (
    SELECT id, row_number() OVER (ORDER BY k, eliminated_round DESC NULLS FIRST, created_at) AS rk
      FROM keyed
  )
  UPDATE public.tournament_entrants e SET final_rank = ranked.rk
    FROM ranked WHERE e.id = ranked.id;

  v_net := round(t.prize_pool_ar * (100 - t.platform_pct) / 100) + t.admin_prize_pool_ar;
  v_pcts := ARRAY[t.prize_1_pct, t.prize_2_pct, t.prize_3_pct];

  FOR r IN SELECT * FROM public.tournament_entrants
            WHERE tournament_id = _tid AND final_rank IS NOT NULL AND final_rank <= t.winners_count
            ORDER BY final_rank LOOP
    i := r.final_rank;
    v_amt := round(v_net * COALESCE(v_pcts[i],0) / 100);
    IF v_amt > 0 AND r.user_id IS NOT NULL AND NOT r.is_bot AND NOT t.is_simulation THEN
      PERFORM public.credit_user_balance(r.user_id, v_amt, 'tournament_prize', _tid,
        'Récompense tournoi: ' || t.name, jsonb_build_object('rank', i));
    END IF;
    PERFORM public._t_notify(r.id, '🏆 Tournoi terminé',
      'Vous terminez ' || i || 'e. Gain : ' || v_amt || ' Ar', '/tournaments/' || _tid);
  END LOOP;

  UPDATE public.tournaments SET status = 'finished', stage = 'done', finished_at = now() WHERE id = _tid;
END $function$
;

CREATE OR REPLACE FUNCTION public._t_launch_match(_match_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  m public.tournament_matches%ROWTYPE;
  t public.tournaments%ROWTYPE;
  v_host uuid; v_gid uuid; v_slot int := 0; e record; v_n int;
  v_colors text[] := ARRAY['red','blue','green','yellow'];
BEGIN
  SELECT * INTO m FROM public.tournament_matches WHERE id = _match_id FOR UPDATE;
  IF m.id IS NULL OR m.status <> 'scheduled' THEN RETURN; END IF;
  SELECT * INTO t FROM public.tournaments WHERE id = m.tournament_id;
  v_n := array_length(m.entrant_ids, 1);

  IF t.is_simulation THEN
    UPDATE public.tournament_matches
       SET status = 'running', game_id = NULL, started_at = now(),
           deadline_at = now() + make_interval(mins => t.lobby_minutes)
     WHERE id = _match_id;
    RETURN;
  END IF;

  SELECT user_id INTO v_host FROM public.tournament_entrants
   WHERE id = ANY(m.entrant_ids) AND user_id IS NOT NULL LIMIT 1;
  v_host := COALESCE(v_host, t.created_by);
  IF v_host IS NULL THEN RETURN; END IF;

  IF t.game_slug = 'ludo' THEN
    INSERT INTO public.ludo_games(host_id, max_players, stake, pot, commission_pct, is_private, mode, status, ready_deadline, auto_move)
      VALUES (v_host, v_n, 0, 0, 0, TRUE, 'classic', 'open', now() + make_interval(mins => t.lobby_minutes), TRUE)
      RETURNING id INTO v_gid;
    FOR e IN SELECT * FROM public.tournament_entrants WHERE id = ANY(m.entrant_ids)
             ORDER BY array_position(m.entrant_ids, id) LOOP
      INSERT INTO public.ludo_participants(game_id, user_id, slot, color, display_name, is_bot, bot_name, ready)
        VALUES (v_gid, e.user_id, v_slot, v_colors[v_slot+1], e.display_name, e.is_bot,
                CASE WHEN e.is_bot THEN e.display_name END, e.is_bot);
      v_slot := v_slot + 1;
    END LOOP;
  ELSE
    INSERT INTO public.domino_games(host_id, max_players, stake, pot, commission_pct, is_private, mode, status, target_score, first_tile_rule)
      VALUES (v_host, v_n, 0, 0, 0, TRUE, 'classic', 'open', 0, 'libre')
      RETURNING id INTO v_gid;
    FOR e IN SELECT * FROM public.tournament_entrants WHERE id = ANY(m.entrant_ids)
             ORDER BY array_position(m.entrant_ids, id) LOOP
      INSERT INTO public.domino_participants(game_id, user_id, slot, display_name, is_bot, bot_name, ready)
        VALUES (v_gid, e.user_id, v_slot, e.display_name, e.is_bot,
                CASE WHEN e.is_bot THEN e.display_name END, e.is_bot);
      v_slot := v_slot + 1;
    END LOOP;
  END IF;

  UPDATE public.tournament_matches
     SET status = 'running', game_id = v_gid, started_at = now(),
         deadline_at = now() + make_interval(mins => t.lobby_minutes)
   WHERE id = _match_id;

  FOR e IN SELECT id FROM public.tournament_entrants WHERE id = ANY(m.entrant_ids) LOOP
    PERFORM public._t_notify(e.id, '🎮 Votre match est prêt',
      'Rejoignez la table maintenant, vous avez ' || t.lobby_minutes || ' minutes.',
      '/' || t.game_slug || '/' || v_gid);
  END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION public._t_match_finish(_match_id uuid, _winner uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE m public.tournament_matches%ROWTYPE; e uuid;
BEGIN
  SELECT * INTO m FROM public.tournament_matches WHERE id = _match_id FOR UPDATE;
  IF m.id IS NULL OR m.status = 'finished' THEN RETURN; END IF;

  UPDATE public.tournament_matches
     SET status = 'finished', winner_entrant_id = _winner, finished_at = now()
   WHERE id = _match_id;

  IF m.phase = 'pool' AND m.pool_id IS NOT NULL THEN
    PERFORM public._t_pool_recompute(m.pool_id);
  ELSE
    FOREACH e IN ARRAY m.entrant_ids LOOP
      IF _winner IS NULL OR e <> _winner THEN
        UPDATE public.tournament_entrants
           SET status = 'eliminated', eliminated_round = m.round
         WHERE id = e AND status = 'active';
      END IF;
    END LOOP;
  END IF;

  FOREACH e IN ARRAY m.entrant_ids LOOP
    IF _winner IS NOT NULL AND e = _winner THEN
      PERFORM public._t_notify(e, '✅ Match gagné', 'Vous passez à la suite du tournoi.', '/tournaments/' || m.tournament_id);
    ELSIF _winner IS NULL THEN
      PERFORM public._t_notify(e, '🤝 Match nul', 'Le match se termine sans vainqueur.', '/tournaments/' || m.tournament_id);
    ELSE
      PERFORM public._t_notify(e, '❌ Match perdu', 'Merci d''avoir participé.', '/tournaments/' || m.tournament_id);
    END IF;
  END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION public._t_notify(_entrant uuid, _title text, _body text, _link text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid;
BEGIN
  SELECT user_id INTO v_uid FROM public.tournament_entrants WHERE id = _entrant;
  IF v_uid IS NULL THEN RETURN; END IF;
  INSERT INTO public.notifications(user_id, kind, title, body, link, ref_id)
  VALUES (v_uid, 'tournoi', _title, _body, _link, _entrant);
END $function$
;

CREATE OR REPLACE FUNCTION public._t_pool_rank(_pool_id uuid)
 RETURNS TABLE(entrant_id uuid, pos integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  WITH base AS (
    SELECT pe.entrant_id, pe.points, pe.wins, pe.id AS tiebreak
      FROM public.tournament_pool_entrants pe
     WHERE pe.pool_id = _pool_id
  ),
  h2h AS (
    SELECT b.entrant_id,
           COALESCE((
             SELECT count(*) FROM public.tournament_matches m
              WHERE m.pool_id = _pool_id AND m.status = 'finished'
                AND m.winner_entrant_id = b.entrant_id
                AND EXISTS (
                  SELECT 1 FROM base b2
                   WHERE b2.entrant_id <> b.entrant_id
                     AND b2.points = b.points
                     AND b2.entrant_id = ANY(m.entrant_ids))
           ), 0) AS h2h_wins
      FROM base b
  )
  SELECT b.entrant_id,
         row_number() OVER (ORDER BY b.points DESC, b.wins DESC, h.h2h_wins DESC, b.tiebreak)::int
    FROM base b JOIN h2h h ON h.entrant_id = b.entrant_id;
$function$
;

CREATE OR REPLACE FUNCTION public._t_pool_recompute(_pool_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.tournament_pool_entrants pe
     SET played = COALESCE(s.played, 0),
         wins   = COALESCE(s.wins, 0),
         points = COALESCE(s.points, 0)
    FROM (
      SELECT x.entrant_id,
             count(*) AS played,
             count(*) FILTER (WHERE x.won) AS wins,
             SUM(CASE WHEN x.won THEN 3 WHEN x.drew THEN 1 ELSE 0 END) AS points
        FROM (
          SELECT u.entrant_id,
                 (m.winner_entrant_id IS NOT NULL AND u.entrant_id = m.winner_entrant_id) AS won,
                 (m.winner_entrant_id IS NULL) AS drew
            FROM public.tournament_matches m
            CROSS JOIN LATERAL unnest(m.entrant_ids) AS u(entrant_id)
           WHERE m.pool_id = _pool_id AND m.status = 'finished'
        ) x
       GROUP BY x.entrant_id
    ) s
   WHERE pe.pool_id = _pool_id AND pe.entrant_id = s.entrant_id;

  UPDATE public.tournament_pool_entrants pe
     SET played = 0, wins = 0, points = 0
   WHERE pe.pool_id = _pool_id
     AND NOT EXISTS (
       SELECT 1 FROM public.tournament_matches m
        WHERE m.pool_id = _pool_id AND m.status = 'finished'
          AND pe.entrant_id = ANY(m.entrant_ids));
END $function$
;

CREATE OR REPLACE FUNCTION public._t_sim_resolve(_tid uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE m record; v_win uuid; v_n int := 0;
BEGIN
  FOR m IN SELECT * FROM public.tournament_matches
            WHERE tournament_id = _tid AND status = 'running' AND game_id IS NULL LOOP
    v_win := m.entrant_ids[1 + floor(random() * COALESCE(array_length(m.entrant_ids,1),1))::int];
    -- 12% de matchs nuls en phase de poule (test du départage)
    IF m.phase = 'pool' AND random() < 0.12 THEN v_win := NULL; END IF;
    PERFORM public._t_match_finish(m.id, v_win);
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END $function$
;

CREATE OR REPLACE FUNCTION public._t_touch()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN NEW.updated_at := now(); RETURN NEW; END $function$
;

CREATE OR REPLACE FUNCTION public._tmatch_set_join_deadline()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_secs INT;
BEGIN
  IF NEW.join_deadline IS NULL AND NEW.status = 'pending' AND NOT NEW.is_bye THEN
    SELECT COALESCE(join_timeout_secs, 120) INTO v_secs FROM public.tournaments WHERE id = NEW.tournament_id;
    NEW.join_deadline := now() + (v_secs || ' seconds')::interval;
  END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._touch_shuffle_draft()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN NEW.updated_at := now(); RETURN NEW; END $function$
;

CREATE OR REPLACE FUNCTION public._tourn_assign_ludo_waves(_tid uuid, _round integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_lim int; v_cnt int;
BEGIN
  v_lim := public._tourn_ludo_limit();
  SELECT count(*) INTO v_cnt FROM public.tournament_matches
   WHERE tournament_id = _tid AND round = _round
     AND is_bye = false AND COALESCE(is_third_place,false) = false;

  WITH r AS (
    SELECT id, (ROW_NUMBER() OVER (ORDER BY match_index) - 1)::int AS ord
      FROM public.tournament_matches
     WHERE tournament_id = _tid AND round = _round
       AND is_bye = false AND COALESCE(is_third_place,false) = false
  )
  UPDATE public.tournament_matches m
     SET wave = public._tourn_wave_for(r.ord, v_cnt, v_lim)
    FROM r WHERE m.id = r.id;

  -- Petite finale / byes : vague 1 (peu de charge)
  UPDATE public.tournament_matches
     SET wave = 1
   WHERE tournament_id = _tid AND round = _round AND wave IS NULL;

  -- Nouveau round → on annule tout compte à rebours résiduel
  UPDATE public.tournaments SET ludo_next_wave_at = NULL WHERE id = _tid;
END $function$
;

CREATE OR REPLACE FUNCTION public._tourn_launch_after_finish()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.status IN ('finished','cancelled')
     AND (OLD.status IS NULL OR OLD.status NOT IN ('finished','cancelled'))
     AND NEW.tournament_match_id IS NOT NULL THEN
    -- placeholder: real logic handled elsewhere via cron/other triggers
    PERFORM 1;
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._tourn_launch_ludo_match(_match_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  m public.tournament_matches%ROWTYPE;
  v_game_id uuid; v_first uuid; v_size int; v_slot int := 0; v_pid uuid; v_color text; v_name text;
BEGIN
  SELECT * INTO m FROM public.tournament_matches WHERE id = _match_id FOR UPDATE;
  IF m.id IS NULL OR m.game_id IS NOT NULL OR m.status <> 'pending' OR m.is_bye THEN
    RETURN m.game_id;
  END IF;
  v_first := m.player_ids[1];
  v_size := GREATEST(COALESCE(array_length(m.player_ids,1),2), 2);
  INSERT INTO public.ludo_games(host_id, max_players, stake, pot, commission_pct, room_code, is_private, mode, tournament_match_id, status)
    VALUES (v_first, v_size, 0, 0, 0, NULL, TRUE, 'classic', m.id, 'open')
    RETURNING id INTO v_game_id;
  FOREACH v_pid IN ARRAY m.player_ids LOOP
    v_color := (ARRAY['red','blue','green','yellow'])[v_slot+1];
    SELECT pseudo INTO v_name FROM public.profiles WHERE id = v_pid;
    INSERT INTO public.ludo_participants(game_id, user_id, slot, color, display_name)
      VALUES (v_game_id, v_pid, v_slot, v_color, COALESCE(v_name,'Joueur'));
    v_slot := v_slot + 1;
  END LOOP;
  UPDATE public.tournament_matches SET game_id = v_game_id, status = 'running' WHERE id = m.id;
  RETURN v_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public._tourn_ludo_active_count()
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT count(*)::int FROM public.ludo_games g
    JOIN public.tournament_matches tm ON tm.id = g.tournament_match_id
   WHERE g.status IN ('open','playing')
$function$
;

CREATE OR REPLACE FUNCTION public._tourn_ludo_limit()
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT COALESCE(NULLIF(tourn_max_concurrent_ludo, 0), 2147483647) FROM public.app_settings WHERE id = 1
$function$
;

CREATE OR REPLACE FUNCTION public._tourn_wave_for(_idx integer, _total integer, _limit integer)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
DECLARE v_full int; v_rem int; v_threshold int; v_merge boolean;
BEGIN
  IF _limit <= 0 OR _total <= _limit THEN RETURN 1; END IF;
  v_full      := _total / _limit;
  v_rem       := _total % _limit;
  v_threshold := (_limit + 1) / 2;                       -- ceil(limit/2)
  v_merge     := (v_rem > 0 AND v_rem < v_threshold);    -- petit reste → fusionne
  IF v_rem = 0 THEN
    RETURN _idx / _limit + 1;
  ELSIF v_merge THEN
    IF _idx < (v_full - 1) * _limit THEN
      RETURN _idx / _limit + 1;
    ELSE
      RETURN v_full;                                     -- dernière vague élargie
    END IF;
  ELSE
    RETURN _idx / _limit + 1;                            -- reste = vague à part
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public._tpool_notify(_uids uuid[], _title text, _body text, _tid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE u uuid;
BEGIN
  IF _uids IS NULL THEN RETURN; END IF;
  FOREACH u IN ARRAY _uids LOOP
    IF u IS NOT NULL THEN
      INSERT INTO public.notifications(user_id, kind, title, body, link)
        VALUES (u, 'tournament', _title, _body, '/tournaments/' || _tid::text);
    END IF;
  END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION public._tpool_touch()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN NEW.updated_at = now(); RETURN NEW; END $function$
;

CREATE OR REPLACE FUNCTION public._trg_afk_warning_non_ludo()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_max INT; v_slug TEXT; v_key TEXT; v_count INT; v_name TEXT;
BEGIN
  IF NEW.status <> 'playing' OR COALESCE(NEW.paused, FALSE) THEN RETURN NEW; END IF;
  IF NEW.turn_skips IS NOT DISTINCT FROM OLD.turn_skips THEN RETURN NEW; END IF;
  v_slug := CASE TG_TABLE_NAME WHEN 'chess_games' THEN 'chess' WHEN 'fanorona_games' THEN 'fanorona'
    WHEN 'domino_games' THEN 'domino' WHEN 'rami_games' THEN 'rami' WHEN 'poker_games' THEN 'poker' ELSE NULL END;
  IF v_slug IS NULL THEN RETURN NEW; END IF;
  SELECT max_turn_skips INTO v_max FROM public.game_configs WHERE slug = v_slug;
  IF v_max IS NULL OR v_max <= 1 THEN RETURN NEW; END IF;
  FOR v_key, v_count IN SELECT key, value::int FROM jsonb_each_text(NEW.turn_skips) LOOP
    IF v_count = v_max - 1 THEN
      SELECT pseudo INTO v_name FROM public.profiles WHERE id = v_key::uuid;
      NEW.afk_warning := jsonb_build_object('uid', v_key, 'name', COALESCE(v_name, 'Joueur'),
        'skips', v_count, 'max', v_max, 'votes', '[]'::jsonb, 'votes_needed', 0,
        'ts', extract(epoch from now())::bigint);
      RETURN NEW;
    END IF;
  END LOOP;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._trg_balance_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.balance_ar IS DISTINCT FROM OLD.balance_ar THEN
    INSERT INTO public.balance_audit_log(user_id, old_balance, new_balance, delta, db_user, txid)
    VALUES (NEW.id, OLD.balance_ar, NEW.balance_ar, NEW.balance_ar - OLD.balance_ar, current_user, txid_current());
  END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._trg_check_achievements_on_win()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.total_wins IS DISTINCT FROM OLD.total_wins OR NEW.daily_streak IS DISTINCT FROM OLD.daily_streak THEN
    PERFORM public.check_and_award_achievements(NEW.id);
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._trg_domino_participant_end_check()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.is_bot=false AND COALESCE(NEW.forfeited,false) IS DISTINCT FROM COALESCE(OLD.forfeited,false) THEN
    PERFORM public._maybe_end_bot_only_domino(NEW.game_id);
  END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._trg_fanorona_participant_end_check()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF COALESCE(NEW.forfeited,false) IS DISTINCT FROM COALESCE(OLD.forfeited,false) THEN
    PERFORM public._maybe_end_bot_only_fanorona(NEW.game_id);
  END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._trg_ludo_participant_end_check()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.is_bot=false AND (
        COALESCE(NEW.forfeited,false) IS DISTINCT FROM COALESCE(OLD.forfeited,false)
     OR NEW.finish_rank IS DISTINCT FROM OLD.finish_rank
  ) THEN
    PERFORM public._maybe_end_bot_only_ludo(NEW.game_id);
  END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._trg_no_bot_money()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF COALESCE(NEW.is_bot,false) = true AND NEW.balance_ar IS DISTINCT FROM COALESCE(OLD.balance_ar, 0) THEN
    NEW.balance_ar := COALESCE(OLD.balance_ar, 0);
  END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._trg_no_bot_tx()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE v_isbot boolean;
BEGIN
  SELECT COALESCE(is_bot,false) INTO v_isbot FROM public.profiles WHERE id = NEW.user_id;
  IF v_isbot THEN RETURN NULL; END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._trg_pool_match_finished()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_loser uuid;
BEGIN
  IF COALESCE(NEW.phase,'final') <> 'pool' THEN RETURN NEW; END IF;
  IF NEW.status NOT IN ('finished','forfeit') OR OLD.status = NEW.status THEN RETURN NEW; END IF;

  PERFORM public._tournament_pool_recount(NEW.pool_id);

  IF NEW.winner_id IS NOT NULL THEN
    SELECT p INTO v_loser FROM unnest(NEW.player_ids) p WHERE p <> NEW.winner_id LIMIT 1;
    PERFORM public._tpool_notify(ARRAY[NEW.winner_id], '🏆 Match gagné (+3 pts)',
      'Bravo ! Ton classement de poule est mis à jour.', NEW.tournament_id);
    IF v_loser IS NOT NULL THEN
      PERFORM public._tpool_notify(ARRAY[v_loser], '❌ Match perdu',
        'Pas de points cette fois. Prochain match bientôt.', NEW.tournament_id);
    END IF;
  END IF;

  PERFORM public.tournament_pump(NEW.tournament_id);
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._trg_rami_participant_end_check()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF COALESCE(NEW.forfeited,false) IS DISTINCT FROM COALESCE(OLD.forfeited,false) THEN
    PERFORM public._maybe_end_bot_only_rami(NEW.game_id);
  END IF;
  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public._trg_third_place_auto_payout()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  trn         record;
  dist        jsonb;
  v_prize     numeric;
  v_third_amt numeric;
BEGIN
  IF COALESCE(NEW.is_third_place, false) = false THEN RETURN NEW; END IF;
  IF NEW.status NOT IN ('finished','forfeit') THEN RETURN NEW; END IF;
  IF NEW.winner_id IS NULL THEN RETURN NEW; END IF;
  IF OLD.status = NEW.status AND OLD.winner_id IS NOT DISTINCT FROM NEW.winner_id THEN
    RETURN NEW;
  END IF;

  SELECT * INTO trn FROM public.tournaments WHERE id = NEW.tournament_id FOR UPDATE;
  IF trn IS NULL THEN RETURN NEW; END IF;
  IF trn.third_prize_paid_at IS NOT NULL THEN RETURN NEW; END IF;

  v_prize := COALESCE(trn.prize_pool, 0);
  dist    := COALESCE(trn.reward_distribution,
                      '{"first":60,"second":20,"third":10,"platform":10}'::jsonb);
  v_third_amt := ROUND(v_prize * COALESCE((dist->>'third')::numeric, 10) / 100, 0);

  IF v_prize > 0 AND v_third_amt > 0 THEN
    UPDATE public.profiles SET balance_ar = balance_ar + v_third_amt
     WHERE id = NEW.winner_id;
    INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
      VALUES (NEW.winner_id, 'tournament_win', v_third_amt, NEW.tournament_id,
              '🥉 3e — Tournoi ' || COALESCE(trn.name,''));
  END IF;

  UPDATE public.tournaments
     SET third_place_id = NEW.winner_id,
         third_prize_paid_at = now()
   WHERE id = NEW.tournament_id;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._trg_third_place_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  trn      record;
  pid      uuid;
  v_title  text;
  v_body   text;
  v_link   text;
BEGIN
  IF COALESCE(NEW.is_third_place, false) = false THEN RETURN NEW; END IF;
  IF COALESCE(array_length(NEW.player_ids, 1), 0) < 1 THEN RETURN NEW; END IF;

  SELECT id, name, game_slug INTO trn FROM public.tournaments WHERE id = NEW.tournament_id;
  IF trn.id IS NULL THEN RETURN NEW; END IF;

  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    v_title := '🥉 Petite finale programmée';
    v_body  := 'Tu joues bientôt pour la 3e place du tournoi « ' || COALESCE(trn.name,'') || ' ». Prépare-toi !';
    v_link  := '/tournaments/' || trn.id;
    FOREACH pid IN ARRAY NEW.player_ids LOOP
      IF pid IS NOT NULL THEN
        INSERT INTO public.notifications(user_id, kind, type, title, body, link, ref_id)
        VALUES (pid, 'tournament', 'third_place_scheduled', v_title, v_body, v_link, NEW.id);
      END IF;
    END LOOP;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
     AND OLD.game_id IS NULL
     AND NEW.game_id IS NOT NULL THEN
    v_title := '⚔️ Petite finale : ça démarre !';
    v_body  := 'Ta petite finale du tournoi « ' || COALESCE(trn.name,'') || ' » vient de commencer. Rejoins la partie maintenant.';
    v_link  := '/' || COALESCE(trn.game_slug, 'ludo') || '/' || NEW.game_id::text;
    FOREACH pid IN ARRAY NEW.player_ids LOOP
      IF pid IS NOT NULL THEN
        INSERT INTO public.notifications(user_id, kind, type, title, body, link, ref_id)
        VALUES (pid, 'tournament', 'third_place_started', v_title, v_body, v_link, NEW.id);
      END IF;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$function$
;

-- ═══════════ 0007_functions_05.sql ═══════════
-- 0007_functions_05.sql
-- Fonctions et procédures (5/12)

CREATE OR REPLACE FUNCTION public._trg_third_place_set_deadline()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF COALESCE(NEW.is_third_place, false) = true
     AND NEW.status = 'pending'
     AND NEW.join_deadline IS NULL THEN
    NEW.join_deadline := now() + interval '15 minutes';
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._try_unlock_referral(_uid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- No-op : la commission de parrainage se calcule maintenant à chaque mise.
  RETURN;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._update_player_stats_on_win()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status <> 'finished' AND NEW.status = 'finished' AND NEW.winner_id IS NOT NULL THEN
    UPDATE public.profiles SET
      total_wins   = COALESCE(total_wins, 0) + 1,
      total_games  = COALESCE(total_games, 0) + 1,
      player_level = CASE
        WHEN COALESCE(total_wins,0)+1 >= 200 THEN 10
        WHEN COALESCE(total_wins,0)+1 >= 100 THEN 9
        WHEN COALESCE(total_wins,0)+1 >= 60  THEN 8
        WHEN COALESCE(total_wins,0)+1 >= 35  THEN 7
        WHEN COALESCE(total_wins,0)+1 >= 20  THEN 6
        WHEN COALESCE(total_wins,0)+1 >= 12  THEN 5
        WHEN COALESCE(total_wins,0)+1 >= 7   THEN 4
        WHEN COALESCE(total_wins,0)+1 >= 3   THEN 3
        WHEN COALESCE(total_wins,0)+1 >= 1   THEN 2
        ELSE 1 END
    WHERE id = NEW.winner_id;
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public._validate_app_settings(_row app_settings)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public._is_valid_mg_phone(_row.mvola_phone)      THEN RETURN 'Numéro MVola invalide (format attendu : +261 34 12 345 67 ou 034 12 345 67).'; END IF;
  IF NOT public._is_valid_mg_phone(_row.orange_phone)     THEN RETURN 'Numéro Orange Money invalide.'; END IF;
  IF NOT public._is_valid_mg_phone(_row.airtel_phone)     THEN RETURN 'Numéro Airtel Money invalide.'; END IF;
  IF NOT public._is_valid_mg_phone(_row.admin_phone)      THEN RETURN 'Numéro admin invalide.'; END IF;
  IF NOT public._is_valid_mg_phone(_row.contact_phone)    THEN RETURN 'Numéro de téléphone contact invalide.'; END IF;
  IF NOT public._is_valid_mg_phone(_row.contact_whatsapp) THEN RETURN 'Numéro WhatsApp invalide.'; END IF;
  IF _row.mvola_name  IS NOT NULL AND char_length(_row.mvola_name)  > 80 THEN RETURN 'Nom du titulaire MVola trop long (max 80).'; END IF;
  IF _row.orange_name IS NOT NULL AND char_length(_row.orange_name) > 80 THEN RETURN 'Nom du titulaire Orange trop long (max 80).'; END IF;
  IF _row.airtel_name IS NOT NULL AND char_length(_row.airtel_name) > 80 THEN RETURN 'Nom du titulaire Airtel trop long (max 80).'; END IF;
  IF NOT public._is_valid_email(_row.contact_email)       THEN RETURN 'Adresse email de contact invalide.'; END IF;
  IF NOT public._is_valid_http_url(_row.download_url)     THEN RETURN 'Lien de téléchargement invalide (doit commencer par https://).'; END IF;
  IF NOT public._is_valid_http_url(_row.contact_facebook) THEN RETURN 'URL Facebook invalide (doit commencer par https://).'; END IF;
  IF _row.signup_bonus IS NOT NULL AND _row.signup_bonus < 0                                          THEN RETURN 'Le bonus d''inscription doit être supérieur ou égal à 0.'; END IF;
  IF _row.min_deposit  IS NOT NULL AND _row.min_deposit  < 0                                          THEN RETURN 'Le dépôt minimum doit être supérieur ou égal à 0.'; END IF;
  IF _row.min_withdraw IS NOT NULL AND _row.min_withdraw < 0                                          THEN RETURN 'Le retrait minimum doit être supérieur ou égal à 0.'; END IF;
  IF _row.game_commission_pct IS NOT NULL AND (_row.game_commission_pct < 0 OR _row.game_commission_pct > 100) THEN RETURN 'La commission sur les parties doit être comprise entre 0 et 100.'; END IF;
  IF _row.referral_pct        IS NOT NULL AND (_row.referral_pct < 0        OR _row.referral_pct > 100)        THEN RETURN 'Le pourcentage de parrainage doit être compris entre 0 et 100.'; END IF;
  IF _row.withdrawal_fee_pct  IS NOT NULL AND (_row.withdrawal_fee_pct < 0  OR _row.withdrawal_fee_pct > 100)  THEN RETURN 'Le pourcentage de frais de retrait doit être compris entre 0 et 100.'; END IF;
  IF _row.max_spectators IS NOT NULL AND (_row.max_spectators < 0 OR _row.max_spectators > 1000)              THEN RETURN 'Le nombre max de spectateurs doit être compris entre 0 et 1000.'; END IF;
  IF _row.afk_t1_max IS NOT NULL AND (_row.afk_t1_max < 0 OR _row.afk_t1_max > 20)                            THEN RETURN 'Le seuil AFK T1 doit être compris entre 0 et 20.'; END IF;
  IF _row.afk_t2_max IS NOT NULL AND (_row.afk_t2_max < 0 OR _row.afk_t2_max > 20)                            THEN RETURN 'Le seuil AFK T2 doit être compris entre 0 et 20.'; END IF;
  RETURN NULL;
END;$function$
;

CREATE OR REPLACE FUNCTION public.accept_terms()
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  UPDATE public.profiles SET terms_accepted_at = now() WHERE id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.admin_activate_alias(p_alias_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_alias RECORD;
  v_real_pseudo TEXT;
  v_real_avatar TEXT;
  v_real_wins INT;
  v_real_games INT;
  v_real_level INT;
  v_current RECORD;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;

  SELECT pseudo, avatar_url, total_wins, total_games, player_level
    INTO v_alias
    FROM public.admin_aliases
    WHERE id = p_alias_id AND admin_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Alias introuvable'; END IF;

  -- Si un alias est déjà actif, sauvegarder ses stats en cours vers admin_aliases
  SELECT ap.is_active, ap.alias_id, ap.real_pseudo, ap.real_avatar_url,
         ap.real_total_wins, ap.real_total_games, ap.real_player_level
    INTO v_current
    FROM public.admin_persona ap WHERE ap.admin_id = auth.uid();

  IF FOUND AND v_current.is_active AND v_current.alias_id IS NOT NULL THEN
    UPDATE public.admin_aliases a
      SET total_wins = p.total_wins,
          total_games = p.total_games,
          player_level = p.player_level
      FROM public.profiles p
      WHERE a.id = v_current.alias_id AND p.id = auth.uid();
    v_real_pseudo := v_current.real_pseudo;
    v_real_avatar := v_current.real_avatar_url;
    v_real_wins := v_current.real_total_wins;
    v_real_games := v_current.real_total_games;
    v_real_level := v_current.real_player_level;
  ELSE
    -- Aucun alias actif : capturer les vraies stats admin
    SELECT pseudo, avatar_url, total_wins, total_games, player_level
      INTO v_real_pseudo, v_real_avatar, v_real_wins, v_real_games, v_real_level
      FROM public.profiles WHERE id = auth.uid();
  END IF;

  INSERT INTO public.admin_persona(
      admin_id, real_pseudo, real_avatar_url,
      real_total_wins, real_total_games, real_player_level,
      persona_pseudo, persona_avatar, alias_id, is_active, activated_at)
    VALUES (auth.uid(), v_real_pseudo, v_real_avatar,
            v_real_wins, v_real_games, v_real_level,
            v_alias.pseudo, v_alias.avatar_url, p_alias_id, true, now())
  ON CONFLICT (admin_id) DO UPDATE
    SET persona_pseudo = EXCLUDED.persona_pseudo,
        persona_avatar = EXCLUDED.persona_avatar,
        alias_id = EXCLUDED.alias_id,
        is_active = true,
        activated_at = now(),
        real_pseudo = EXCLUDED.real_pseudo,
        real_avatar_url = EXCLUDED.real_avatar_url,
        real_total_wins = EXCLUDED.real_total_wins,
        real_total_games = EXCLUDED.real_total_games,
        real_player_level = EXCLUDED.real_player_level;

  -- Charger identité + stats de l'alias sur le profil admin
  UPDATE public.profiles
    SET pseudo = v_alias.pseudo,
        avatar_url = v_alias.avatar_url,
        total_wins = v_alias.total_wins,
        total_games = v_alias.total_games,
        player_level = v_alias.player_level
    WHERE id = auth.uid();
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_activate_persona(p_pseudo text, p_avatar_url text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_real_pseudo TEXT; v_real_avatar_url TEXT;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  SELECT pseudo, avatar_url INTO v_real_pseudo, v_real_avatar_url FROM public.profiles WHERE id = auth.uid();
  INSERT INTO public.admin_persona (admin_id, real_pseudo, real_avatar_url, persona_pseudo, persona_avatar, is_active, activated_at)
  VALUES (auth.uid(), v_real_pseudo, v_real_avatar_url, p_pseudo, p_avatar_url, true, now())
  ON CONFLICT (admin_id) DO UPDATE
    SET persona_pseudo = EXCLUDED.persona_pseudo,
        persona_avatar = EXCLUDED.persona_avatar,
        is_active = true, activated_at = now(),
        real_pseudo = CASE WHEN admin_persona.is_active THEN admin_persona.real_pseudo ELSE EXCLUDED.real_pseudo END,
        real_avatar_url = CASE WHEN admin_persona.is_active THEN admin_persona.real_avatar_url ELSE EXCLUDED.real_avatar_url END;
  UPDATE public.profiles SET pseudo = p_pseudo, avatar_url = p_avatar_url WHERE id = auth.uid();
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_add_bot(_game_id uuid, _bot_name text, _intelligence integer DEFAULT 70, _win_bias integer DEFAULT 0)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g public.ludo_games%ROWTYPE;
  v_slot int;
  v_colors4 text[] := ARRAY['red','blue','green','yellow'];
  v_colors3 text[] := ARRAY['red','green','yellow'];
  v_colors2 text[] := ARRAY['red','yellow'];
  v_color text;
  v_count int;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé à l''administrateur'; END IF;
  SELECT * INTO g FROM public.ludo_games WHERE id=_game_id FOR UPDATE;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  IF g.status <> 'open' THEN RAISE EXCEPTION 'La partie a déjà commencé'; END IF;

  SELECT count(*) INTO v_count FROM public.ludo_participants WHERE game_id=_game_id;
  IF v_count >= g.max_players THEN RAISE EXCEPTION 'Partie pleine'; END IF;

  SELECT s INTO v_slot
    FROM generate_series(0, g.max_players-1) AS s
   WHERE s NOT IN (SELECT slot FROM public.ludo_participants WHERE game_id=_game_id)
   ORDER BY s LIMIT 1;

  IF g.max_players = 2 THEN v_color := v_colors2[v_slot+1];
  ELSIF g.max_players = 3 THEN v_color := v_colors3[v_slot+1];
  ELSE v_color := v_colors4[v_slot+1];
  END IF;

  INSERT INTO public.ludo_participants(
    game_id, user_id, slot, color, is_bot, bot_name, display_name,
    bot_intelligence, bot_win_bias, ready
  ) VALUES (
    _game_id, NULL, v_slot, v_color, TRUE,
    COALESCE(NULLIF(trim(_bot_name),''),'Bot'),
    COALESCE(NULLIF(trim(_bot_name),''),'Bot'),
    GREATEST(0, LEAST(100, COALESCE(_intelligence, 70))),
    GREATEST(-100, LEAST(100, COALESCE(_win_bias, 0))),
    TRUE
  );
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_adjust_balance(_user_id uuid, _amount numeric, _note text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_old numeric; v_new numeric;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  SELECT balance_ar INTO v_old FROM public.profiles WHERE id=_user_id FOR UPDATE;
  UPDATE public.profiles SET balance_ar = balance_ar + _amount WHERE id=_user_id RETURNING balance_ar INTO v_new;
  INSERT INTO public.transactions(user_id,type,amount,note) VALUES (_user_id,'admin_adjust',_amount,COALESCE(_note,'Ajustement admin'));
  PERFORM public._admin_log(_user_id,'adjust_balance',
    jsonb_build_object('balance',v_old),
    jsonb_build_object('balance',v_new,'amount',_amount,'note',_note));
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_align_balances()
 RETURNS TABLE(user_id uuid, pseudo text, old_balance numeric, new_balance numeric, tx_delta numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE r record; v_target numeric; v_tx_delta numeric;
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin'::app_role) THEN RAISE EXCEPTION 'Forbidden'; END IF;
  FOR r IN
    SELECT p.id, p.pseudo, p.balance_ar::numeric AS bal,
           COALESCE((SELECT SUM(amount) FROM public.transactions WHERE user_id = p.id),0)::numeric AS txs
    FROM public.profiles p
    WHERE COALESCE(p.is_bot,false) = false
    FOR UPDATE OF p
  LOOP
    IF r.bal = r.txs THEN CONTINUE; END IF;
    v_target := GREATEST(r.txs, 0);
    v_tx_delta := v_target - r.txs;  -- rend le ledger cohérent avec la nouvelle balance
    -- update balance to target
    UPDATE public.profiles SET balance_ar = v_target WHERE id = r.id;
    -- insère une transaction traçable qui reflète l'ajustement
    IF v_tx_delta <> 0 THEN
      INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
      VALUES (r.id, 'admin_adjust', v_tx_delta, NULL,
              'Réconciliation auto : alignement ledger (ancien solde=' || r.bal || ', txs=' || r.txs || ')');
    END IF;
    user_id := r.id; pseudo := r.pseudo; old_balance := r.bal; new_balance := v_target; tx_delta := v_tx_delta;
    RETURN NEXT;
  END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_announcement_create(_title text, _body text DEFAULT NULL::text, _image_url text DEFAULT NULL::text, _link text DEFAULT NULL::text, _link_label text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _id uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;
  INSERT INTO public.announcements(title, body, image_url, link, link_label, active)
  VALUES (_title, NULLIF(_body,''), NULLIF(_image_url,''), NULLIF(_link,''), NULLIF(_link_label,''), true)
  RETURNING id INTO _id;
  RETURN _id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_announcement_toggle(_id uuid, _active boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  UPDATE public.announcements SET active = _active WHERE id = _id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Annonce introuvable'; END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_audit_unlogged_changes(_hours integer DEFAULT 24)
 RETURNS TABLE(user_id uuid, pseudo text, audit_delta numeric, tx_delta numeric, unlogged numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Admin only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH a AS (
    SELECT bal.user_id AS uid, COALESCE(SUM(bal.delta), 0) AS ad
    FROM public.balance_audit_log bal
    WHERE bal.created_at >= now() - make_interval(hours => _hours)
    GROUP BY bal.user_id
  ), t AS (
    SELECT tx.user_id AS uid, COALESCE(SUM(tx.amount), 0) AS td
    FROM public.transactions tx
    WHERE tx.created_at >= now() - make_interval(hours => _hours)
    GROUP BY tx.user_id
  )
  SELECT COALESCE(a.uid, t.uid), p.pseudo,
         COALESCE(a.ad, 0), COALESCE(t.td, 0),
         COALESCE(a.ad, 0) - COALESCE(t.td, 0)
  FROM a FULL OUTER JOIN t ON t.uid = a.uid
  LEFT JOIN public.profiles p ON p.id = COALESCE(a.uid, t.uid)
  WHERE ABS(COALESCE(a.ad, 0) - COALESCE(t.td, 0)) >= 1
  ORDER BY ABS(COALESCE(a.ad, 0) - COALESCE(t.td, 0)) DESC
  LIMIT 200;
END; $function$
;

CREATE OR REPLACE FUNCTION public.admin_auto_process_expired_matches(_tid uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _res jsonb;
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  -- Applique les forfaits automatiques (fonction existante, sans paramètre)
  PERFORM public.tournament_auto_forfeit_expired();

  -- Démarre les matchs dont tout le monde est prêt
  BEGIN
    PERFORM public.admin_auto_start_ready_matches(_tid);
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN jsonb_build_object('ok', true, 'tournament_id', _tid);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_auto_start_ready_matches(_tid uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_match record;
  v_ready boolean;
  v_pid uuid;
  v_count int := 0;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  FOR v_match IN
    SELECT id, player_ids, player_ready
    FROM public.tournament_matches
    WHERE tournament_id = _tid
      AND status = 'pending'
      AND NOT is_bye
  LOOP
    v_ready := true;
    IF v_match.player_ids IS NULL OR array_length(v_match.player_ids,1) IS NULL THEN
      v_ready := false;
    ELSE
      FOREACH v_pid IN ARRAY v_match.player_ids LOOP
        IF NOT (COALESCE(v_match.player_ready, '{}'::jsonb) ? v_pid::text) THEN
          v_ready := false;
          EXIT;
        END IF;
      END LOOP;
    END IF;

    IF v_ready THEN
      UPDATE public.tournament_matches
        SET join_deadline = now() + interval '5 seconds'
        WHERE id = v_match.id;
      v_count := v_count + 1;
    END IF;
  END LOOP;

  BEGIN
    INSERT INTO public.admin_action_logs(admin_id, action, target_type, target_id, details)
    VALUES (auth.uid(), 'auto_start_ready_matches', 'tournament', _tid,
            jsonb_build_object('started_count', v_count));
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN jsonb_build_object('started', v_count);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_broadcast_delete(_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  UPDATE public.admin_broadcasts SET deleted_at=now() WHERE id=_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_broadcast_send(_message text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_id UUID;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  INSERT INTO public.admin_broadcasts(message) VALUES (_message) RETURNING id INTO v_id;
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_chat_mute(_user_id uuid, _minutes integer, _ban boolean, _reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  INSERT INTO public.chat_mutes(user_id, until, banned, reason)
    VALUES (_user_id, CASE WHEN _minutes>0 THEN now()+(_minutes||' minutes')::interval ELSE NULL END, COALESCE(_ban,false), _reason)
    ON CONFLICT (user_id) DO UPDATE SET until=EXCLUDED.until, banned=EXCLUDED.banned, reason=EXCLUDED.reason;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_chat_unmute(_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  DELETE FROM public.chat_mutes WHERE user_id=_user_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_check_lockout(_user_id uuid)
 RETURNS TABLE(locked boolean, locked_until timestamp with time zone, reason text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    (l.locked_until > now()) AS locked,
    l.locked_until,
    l.reason
  FROM public.admin_lockouts l
  WHERE l.user_id = _user_id
  UNION ALL
  SELECT false, NULL::timestamptz, NULL::text
  WHERE NOT EXISTS (SELECT 1 FROM public.admin_lockouts WHERE user_id = _user_id)
  LIMIT 1;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_close_expired_registrations()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _closed int := 0;
  _r record;
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  FOR _r IN
    SELECT id FROM public.tournaments
    WHERE status IN ('open','registration','registering')
      AND registration_closes_at IS NOT NULL
      AND registration_closes_at < now()
  LOOP
    UPDATE public.tournaments
       SET status = 'closed', updated_at = now()
     WHERE id = _r.id;
    _closed := _closed + 1;
  END LOOP;

  RETURN jsonb_build_object('closed', _closed);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_create_community(_name text, _image_url text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  INSERT INTO public.chat_rooms(type,name,image_url,created_by) VALUES('global',_name,_image_url,auth.uid()) RETURNING id INTO v_id;
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_create_session(_mfa_verified boolean, _approval_id uuid, _ip inet, _user_agent text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _me uuid := auth.uid();
  _fp text;
  _sid uuid;
  _approval public.admin_login_approvals;
BEGIN
  IF _me IS NULL OR NOT public.has_role(_me, 'admin') THEN
    RAISE EXCEPTION 'Not admin';
  END IF;

  IF NOT _mfa_verified THEN
    RAISE EXCEPTION 'MFA obligatoire';
  END IF;

  -- If another admin session exists, an approval or override is REQUIRED
  IF public._admin_has_active_session(_me) THEN
    IF _approval_id IS NULL THEN
      RAISE EXCEPTION 'Approbation d''un admin déjà connecté requise';
    END IF;
    SELECT * INTO _approval FROM public.admin_login_approvals
     WHERE id = _approval_id AND requesting_user_id = _me;
    IF NOT FOUND OR _approval.status NOT IN ('approved','override') THEN
      RAISE EXCEPTION 'Approbation invalide ou refusée';
    END IF;
  END IF;

  _fp := encode(extensions.gen_random_bytes(24), 'hex');

  INSERT INTO public.admin_sessions(
    user_id, session_fingerprint, ip, user_agent,
    mfa_verified, approved_by, override_reason
  ) VALUES (
    _me, _fp, _ip, _user_agent, true,
    _approval.approver_user_id,
    CASE WHEN _approval.status = 'override' THEN _approval.override_reason ELSE NULL END
  ) RETURNING id INTO _sid;

  PERFORM public._admin_notify_others(
    'admin_session_created',
    jsonb_build_object('session_id', _sid, 'user_id', _me, 'ip', _ip::text,
                       'override', (_approval.status = 'override'))
  );

  RETURN jsonb_build_object('session_id', _sid, 'fingerprint', _fp,
                            'expires_at', now() + interval '8 hours');
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_dashboard_kpis()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v JSONB;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  SELECT jsonb_build_object(
    'users_total', (SELECT count(*) FROM public.profiles),
    'users_online', (SELECT count(*) FROM public.chat_presence WHERE last_seen > now() - interval '2 minutes'),
    'deposits_pending', (SELECT count(*) FROM public.deposits WHERE status = 'pending'),
    'withdrawals_pending', (SELECT count(*) FROM public.withdrawals WHERE status = 'pending'),
    'games_active', (
      (SELECT count(*) FROM public.ludo_games WHERE status = 'playing') +
      (SELECT count(*) FROM public.domino_games WHERE status = 'playing') +
      (SELECT count(*) FROM public.chess_games WHERE status = 'playing') +
      (SELECT count(*) FROM public.fanorona_games WHERE status = 'playing') +
      (SELECT count(*) FROM public.rami_games WHERE status = 'playing') +
      (SELECT count(*) FROM public.poker_games WHERE status = 'playing')
    ),
    'tournaments_active', (SELECT count(*) FROM public.tournaments WHERE status IN ('open','running')),
    'claims_pending', (SELECT count(*) FROM public.tournament_claims WHERE status = 'pending'),
    'bug_reports_open', (SELECT count(*) FROM public.bug_reports WHERE status IN ('open','in_progress')),
    'revenue_24h', COALESCE((SELECT sum(amount) FROM public.transactions WHERE type = 'commission' AND created_at > now() - interval '24 hours'), 0),
    'revenue_7d', COALESCE((SELECT sum(amount) FROM public.transactions WHERE type = 'commission' AND created_at > now() - interval '7 days'), 0)
  ) INTO v;
  RETURN v;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_dashboard_totals()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v jsonb;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  SELECT jsonb_build_object(
    'total_deposits', COALESCE((SELECT SUM(amount) FROM public.deposits WHERE status='approved'),0),
    'total_withdrawals', COALESCE((SELECT SUM(amount) FROM public.withdrawals WHERE status='approved'),0),
    'total_commission', COALESCE((SELECT SUM(pot * commission_pct / 100.0) FROM public.ludo_games WHERE status='finished' AND winner_id IS NOT NULL),0),
    'total_users', (SELECT count(*) FROM public.profiles),
    'total_games', (SELECT count(*) FROM public.ludo_games WHERE status='finished'),
    'open_games', (SELECT count(*) FROM public.ludo_games WHERE status='open'),
    'playing_games', (SELECT count(*) FROM public.ludo_games WHERE status='playing')
  ) INTO v;
  RETURN v;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_deactivate_persona()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_persona RECORD;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;

  SELECT * INTO v_persona FROM public.admin_persona WHERE admin_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Aucun alias actif trouvé'; END IF;

  IF v_persona.alias_id IS NOT NULL THEN
    UPDATE public.admin_aliases a
      SET total_wins = p.total_wins,
          total_games = p.total_games,
          player_level = p.player_level
      FROM public.profiles p
      WHERE a.id = v_persona.alias_id AND p.id = auth.uid();
  END IF;

  UPDATE public.profiles
    SET pseudo = v_persona.real_pseudo,
        avatar_url = v_persona.real_avatar_url,
        total_wins = v_persona.real_total_wins,
        total_games = v_persona.real_total_games,
        player_level = v_persona.real_player_level
    WHERE id = auth.uid();

  UPDATE public.admin_persona SET is_active = false WHERE admin_id = auth.uid();
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_delete_alias(p_alias_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  IF EXISTS (SELECT 1 FROM public.admin_persona WHERE admin_id = auth.uid() AND alias_id = p_alias_id AND is_active) THEN
    PERFORM public.admin_deactivate_persona();
  END IF;
  DELETE FROM public.admin_aliases WHERE id = p_alias_id AND admin_id = auth.uid();
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_delete_community(_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  DELETE FROM public.chat_rooms WHERE id=_room_id AND type='global';
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_delete_game(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g public.ludo_games%ROWTYPE; p RECORD;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  SELECT * INTO g FROM public.ludo_games WHERE id=_game_id FOR UPDATE;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  -- refund all human participants their stake
  FOR p IN SELECT user_id FROM public.ludo_participants
           WHERE game_id=_game_id AND user_id IS NOT NULL AND is_bot=false
  LOOP
    UPDATE public.profiles SET balance_ar = balance_ar + g.stake WHERE id=p.user_id;
    INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
      VALUES (p.user_id,'refund',g.stake,g.id,'Partie supprimée par l''admin');
  END LOOP;
  INSERT INTO public.admin_logs(admin_id, action, target_user_id, old_value)
    VALUES (auth.uid(), 'admin_delete_game', g.host_id, to_jsonb(g));
  DELETE FROM public.ludo_games WHERE id=_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_dm_send(_user_id uuid, _message text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_id UUID;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  INSERT INTO public.admin_user_messages(user_id,from_admin,message)
    VALUES (_user_id, TRUE, _message) RETURNING id INTO v_id;
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_finance_kpi()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v jsonb;
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin'::app_role) THEN RAISE EXCEPTION 'Forbidden'; END IF;
  SELECT jsonb_build_object(
    'total_deposits',   COALESCE((SELECT SUM(amount) FROM public.transactions WHERE type = 'deposit'),0),
    'total_withdraws',  COALESCE((SELECT -SUM(amount) FROM public.transactions WHERE type = 'withdraw'),0),
    'total_stakes',     COALESCE((SELECT -SUM(amount) FROM public.transactions WHERE type LIKE '%stake' OR type = 'stake'),0),
    'total_payouts',    COALESCE((SELECT SUM(amount) FROM public.transactions WHERE type LIKE '%win' OR type LIKE '%payout' OR type = 'win'),0),
    'total_refunds',    COALESCE((SELECT SUM(amount) FROM public.transactions WHERE type LIKE '%refund' OR type = 'refund'),0),
    'total_bonus',      COALESCE((SELECT SUM(amount) FROM public.transactions WHERE type IN ('bonus','referral')),0),
    'sum_balances',     COALESCE((SELECT SUM(balance_ar) FROM public.profiles WHERE COALESCE(is_bot,false)=false),0),
    'sum_transactions', COALESCE((SELECT SUM(amount) FROM public.transactions WHERE user_id IN (SELECT id FROM public.profiles WHERE COALESCE(is_bot,false)=false)),0),
    'pending_withdrawals', COALESCE((SELECT SUM(amount) FROM public.withdrawals WHERE status = 'pending'),0),
    'pending_deposits',    COALESCE((SELECT SUM(amount) FROM public.deposits WHERE status = 'pending'),0)
  ) INTO v;
  v := v || jsonb_build_object('reconciliation_gap', (v->>'sum_balances')::numeric - (v->>'sum_transactions')::numeric);
  RETURN v;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_force_finish_game(_game_id uuid, _winner_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g public.ludo_games%ROWTYPE; p RECORD;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  SELECT * INTO g FROM public.ludo_games WHERE id=_game_id FOR UPDATE;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  IF g.status = 'finished' THEN RAISE EXCEPTION 'Déjà terminée'; END IF;

  IF _winner_id IS NOT NULL THEN
    PERFORM public.finish_game(_game_id, _winner_id);
  ELSE
    -- refund all human participants
    FOR p IN SELECT user_id FROM public.ludo_participants
             WHERE game_id=_game_id AND user_id IS NOT NULL AND is_bot=false
    LOOP
      UPDATE public.profiles SET balance_ar = balance_ar + g.stake WHERE id=p.user_id;
      INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
        VALUES (p.user_id,'refund',g.stake,g.id,'Partie annulée par l''admin');
    END LOOP;
    UPDATE public.ludo_games SET status='finished', finished_at=now(), winner_id=NULL WHERE id=_game_id;
  END IF;
  INSERT INTO public.admin_logs(admin_id, action, target_user_id)
    VALUES (auth.uid(), 'admin_force_finish_game', _winner_id);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_force_match_result(_mid uuid, _winner_id uuid, _reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_match record;
  v_game_status text;
  v_can_refund boolean := true;
  v_pid uuid;
  v_refunded_count int := 0;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  SELECT * INTO v_match FROM public.tournament_matches WHERE id = _mid FOR UPDATE;
  IF v_match IS NULL THEN RAISE EXCEPTION 'Match introuvable'; END IF;
  IF v_match.player_ids IS NULL OR array_length(v_match.player_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'Aucun joueur dans ce match';
  END IF;
  IF NOT (_winner_id = ANY(v_match.player_ids)) THEN
    RAISE EXCEPTION 'Le vainqueur doit être un joueur du match';
  END IF;

  UPDATE public.tournament_matches
    SET status = 'forfeit',
        winner_id = _winner_id,
        finished_at = now(),
        admin_notes = COALESCE(admin_notes || ' | ', '') ||
          'Forfait forcé par admin (vainqueur: ' || _winner_id::text || '): ' ||
          COALESCE(NULLIF(_reason, ''), 'sans raison')
    WHERE id = _mid;

  -- Cancel associated game if not started; refund losers only when game hadn't started
  IF v_match.game_id IS NOT NULL THEN
    SELECT status INTO v_game_status FROM public.ludo_games WHERE id = v_match.game_id;
    IF v_game_status IS NOT NULL AND v_game_status NOT IN ('open') THEN
      v_can_refund := false;
    ELSE
      UPDATE public.ludo_games SET status = 'cancelled' WHERE id = v_match.game_id AND status = 'open';
    END IF;
  END IF;

  IF v_can_refund THEN
    FOREACH v_pid IN ARRAY v_match.player_ids LOOP
      IF v_pid <> _winner_id THEN
        IF public._tournament_refund_participant(
             v_match.tournament_id, _mid, v_pid,
             'Forfait forcé par admin: ' || COALESCE(NULLIF(_reason,''),'sans raison')
           ) THEN
          v_refunded_count := v_refunded_count + 1;
        END IF;
      END IF;
    END LOOP;
  END IF;

  INSERT INTO public.admin_logs(admin_id, action, target_user_id, old_value, new_value)
    VALUES (v_uid, 'admin_force_match_result', _winner_id,
      jsonb_build_object('match_id', _mid, 'previous_status', v_match.status, 'previous_winner_id', v_match.winner_id),
      jsonb_build_object('match_id', _mid, 'winner_id', _winner_id, 'reason', _reason, 'refunded_count', v_refunded_count));

  INSERT INTO public.notifications(user_id, kind, title, body, link, ref_id)
  SELECT
    uid,
    'tournament',
    CASE WHEN uid = _winner_id THEN 'Victoire par forfait' ELSE 'Forfait enregistré' END,
    COALESCE(_reason, 'Décision administrateur'),
    '/tournaments/' || v_match.tournament_id::text,
    _mid
  FROM unnest(v_match.player_ids) AS uid;

  RETURN jsonb_build_object('ok', true, 'winner_id', _winner_id, 'refunded_count', v_refunded_count);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_forfeit_match_player(_mid uuid, _loser_id uuid, _reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_match record;
  v_winner uuid;
  v_game_status text;
  v_refunded boolean := false;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  SELECT * INTO v_match FROM public.tournament_matches WHERE id = _mid FOR UPDATE;
  IF v_match IS NULL THEN RAISE EXCEPTION 'Match introuvable'; END IF;
  IF NOT (_loser_id = ANY(v_match.player_ids)) THEN RAISE EXCEPTION 'Joueur introuvable dans ce match'; END IF;

  SELECT uid INTO v_winner
  FROM unnest(v_match.player_ids) AS uid
  WHERE uid <> _loser_id
  LIMIT 1;

  IF v_winner IS NULL THEN RAISE EXCEPTION 'Impossible de déterminer le vainqueur'; END IF;

  UPDATE public.tournament_matches
    SET status = 'forfeit',
        winner_id = v_winner,
        finished_at = now(),
        admin_notes = COALESCE(admin_notes || ' | ', '') || 'Forfait admin: ' || COALESCE(NULLIF(_reason, ''), 'Sans raison')
    WHERE id = _mid;

  -- If the associated game hasn't started, refund the loser
  IF v_match.game_id IS NOT NULL THEN
    SELECT status INTO v_game_status FROM public.ludo_games WHERE id = v_match.game_id;
    IF v_game_status = 'open' THEN
      UPDATE public.ludo_games SET status = 'cancelled' WHERE id = v_match.game_id AND status = 'open';
      v_refunded := public._tournament_refund_participant(
        v_match.tournament_id, _mid, _loser_id,
        'Forfait admin avant démarrage: ' || COALESCE(NULLIF(_reason,''),'sans raison')
      );
    END IF;
  ELSE
    -- No game yet: safe to refund
    v_refunded := public._tournament_refund_participant(
      v_match.tournament_id, _mid, _loser_id,
      'Forfait admin avant démarrage: ' || COALESCE(NULLIF(_reason,''),'sans raison')
    );
  END IF;

  INSERT INTO public.admin_logs(admin_id, action, target_user_id, old_value, new_value)
    VALUES (v_uid, 'admin_forfeit_match_player', _loser_id,
      jsonb_build_object('match_id', _mid, 'previous_status', v_match.status, 'previous_winner_id', v_match.winner_id),
      jsonb_build_object('match_id', _mid, 'loser_id', _loser_id, 'winner_id', v_winner, 'reason', _reason, 'refunded', v_refunded));

  INSERT INTO public.notifications(user_id, kind, title, body, link, ref_id)
    VALUES
      (v_winner, 'tournament', 'Victoire par forfait', COALESCE(_reason, 'Décision administrateur'), '/tournaments/' || v_match.tournament_id::text, _mid),
      (_loser_id, 'tournament', 'Forfait enregistré', COALESCE(_reason, 'Décision administrateur'), '/tournaments/' || v_match.tournament_id::text, _mid);

  RETURN jsonb_build_object('ok', true, 'winner_id', v_winner, 'refunded', v_refunded);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_games_history(_limit integer DEFAULT 50)
 RETURNS TABLE(id uuid, status game_status, stake numeric, pot numeric, commission_pct numeric, max_players integer, winner_pseudo text, players jsonb, created_at timestamp with time zone, finished_at timestamp with time zone, duration_sec integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  RETURN QUERY
    SELECT g.id, g.status, g.stake, g.pot, g.commission_pct, g.max_players,
      (SELECT pseudo FROM public.profiles WHERE id=g.winner_id),
      COALESCE((SELECT jsonb_agg(jsonb_build_object('name',pp.display_name,'is_bot',pp.is_bot)) FROM public.ludo_participants pp WHERE pp.game_id=g.id),'[]'::jsonb),
      g.created_at, g.finished_at,
      CASE WHEN g.finished_at IS NOT NULL AND g.started_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (g.finished_at - g.started_at))::int ELSE NULL END
    FROM public.ludo_games g ORDER BY g.created_at DESC LIMIT _limit;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_get_forfeit_cron_info()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_row record;
BEGIN
  IF NOT public.has_role(auth.uid(),'admin') THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;
  SELECT jobid, jobname, schedule, active INTO v_row
    FROM cron.job WHERE jobname = 'tournament_auto_forfeit';
  IF v_row.jobid IS NULL THEN
    RETURN jsonb_build_object('exists', false);
  END IF;
  RETURN jsonb_build_object('exists', true, 'jobid', v_row.jobid,
                            'schedule', v_row.schedule, 'active', v_row.active);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_get_fraud_flags(_status text DEFAULT 'pending'::text)
 RETURNS TABLE(id uuid, referrer_id uuid, referee_id uuid, referrer_pseudo text, referee_pseudo text, reason text, details jsonb, status text, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT f.id, f.referrer_id, f.referee_id, p1.pseudo, p2.pseudo,
         f.reason, f.details, f.status, f.created_at
  FROM public.referral_fraud_flags f
  LEFT JOIN public.profiles p1 ON p1.id = f.referrer_id
  LEFT JOIN public.profiles p2 ON p2.id = f.referee_id
  WHERE (_status = 'all' OR f.status = _status)
  ORDER BY f.created_at DESC LIMIT 100;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_get_intervention_dashboard()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_result jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  SELECT jsonb_build_object(
    'running_tournaments', (SELECT count(*) FROM public.tournaments WHERE status = 'running'),
    'open_tournaments', (SELECT count(*) FROM public.tournaments WHERE status = 'open'),
    'running_matches', (SELECT count(*) FROM public.tournament_matches WHERE status = 'running' AND is_bye = false),
    'pending_matches', (SELECT count(*) FROM public.tournament_matches WHERE status IN ('pending','waiting') AND is_bye = false),
    'open_claims', (SELECT count(*) FROM public.tournament_claims WHERE status IN ('pending','reviewing')),
    'suspended_players', (SELECT count(*) FROM public.profiles WHERE suspended_until IS NOT NULL AND suspended_until > now()),
    'banned_players', (SELECT count(*) FROM public.profiles WHERE COALESCE(banned, false) OR COALESCE(is_banned, false)),
    'pending_payouts', 0,
    'stuck_matches', COALESCE((
      SELECT jsonb_agg(x ORDER BY x.join_deadline NULLS LAST)
      FROM (
        SELECT
          m.id,
          m.round,
          m.status,
          m.player_ids,
          m.winner_id,
          m.join_deadline,
          m.tournament_id,
          t.name AS tournament_name
        FROM public.tournament_matches m
        LEFT JOIN public.tournaments t ON t.id = m.tournament_id
        WHERE m.is_bye = false
          AND m.status IN ('pending','waiting','running')
          AND (
            m.join_deadline IS NULL
            OR m.join_deadline < now() + interval '5 minutes'
          )
        ORDER BY m.join_deadline NULLS LAST, m.created_at DESC
        LIMIT 8
      ) x
    ), '[]'::jsonb),
    'recent_claims', COALESCE((
      SELECT jsonb_agg(x ORDER BY x.created_at DESC)
      FROM (
        SELECT
          c.id,
          c.status,
          COALESCE(c.reason, 'general') AS category,
          COALESCE(c.reason, '') AS description,
          c.created_at,
          COALESCE(p.pseudo, 'Joueur') AS claimant_pseudo,
          t.name AS tournament_name,
          t.game_slug
        FROM public.tournament_claims c
        LEFT JOIN public.profiles p ON p.id = c.claimant_id
        LEFT JOIN public.tournaments t ON t.id = c.tournament_id
        WHERE c.status IN ('pending','reviewing')
        ORDER BY c.created_at DESC
        LIMIT 8
      ) x
    ), '[]'::jsonb)
  ) INTO v_result;

  RETURN v_result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_get_persona()
 RETURNS TABLE(is_active boolean, real_pseudo text, real_avatar_url text, persona_pseudo text, persona_avatar text, activated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  RETURN QUERY SELECT ap.is_active, ap.real_pseudo, ap.real_avatar_url, ap.persona_pseudo, ap.persona_avatar, ap.activated_at
    FROM public.admin_persona ap WHERE ap.admin_id = auth.uid();
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_house_income(_since timestamp with time zone DEFAULT (now() - '30 days'::interval))
 RETURNS TABLE(game_type text, commission_total numeric, house_win_total numeric, entries bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    game_type,
    COALESCE(SUM(amount) FILTER (WHERE entry_type='commission'), 0)   AS commission_total,
    COALESCE(SUM(amount) FILTER (WHERE entry_type='house_win'), 0)    AS house_win_total,
    COUNT(*)                                                          AS entries
  FROM public.house_ledger
  WHERE created_at >= _since
    AND public.is_admin()
  GROUP BY game_type
  ORDER BY game_type;
$function$
;

-- ═══════════ 0007_functions_06.sql ═══════════
-- 0007_functions_06.sql
-- Fonctions et procédures (6/12)

CREATE OR REPLACE FUNCTION public.admin_join_game(_game_id uuid, _display_name text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid:=auth.uid(); v_game public.ludo_games%ROWTYPE; v_count int; v_slot int; v_color text;
  v_colors text[]:=ARRAY['red','green','yellow','blue']; v_name text;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  SELECT * INTO v_game FROM public.ludo_games WHERE id=_game_id FOR UPDATE;
  IF v_game.id IS NULL OR v_game.status <> 'open' THEN RAISE EXCEPTION 'Partie non ouverte'; END IF;
  IF EXISTS(SELECT 1 FROM public.ludo_participants WHERE game_id=_game_id AND user_id=v_uid) THEN
    RAISE EXCEPTION 'Déjà inscrit'; END IF;
  SELECT count(*) INTO v_count FROM public.ludo_participants WHERE game_id=_game_id;
  IF v_count >= v_game.max_players THEN RAISE EXCEPTION 'Partie pleine'; END IF;
  v_slot:=v_count; v_color:=v_colors[v_slot+1];
  SELECT COALESCE(NULLIF(_display_name,''), pseudo) INTO v_name FROM public.profiles WHERE id=v_uid;
  INSERT INTO public.ludo_participants(game_id,user_id,slot,color,display_name,ready)
    VALUES (_game_id, v_uid, v_slot, v_color, v_name, true);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_leaderboard_list(_period text DEFAULT 'all'::text, _limit integer DEFAULT 50, _slug text DEFAULT NULL::text)
 RETURNS TABLE(user_id uuid, name text, avatar_url text, wins bigint, total_won numeric, hidden boolean, rank_override integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  RETURN QUERY
  WITH bound AS (
    SELECT CASE _period
      WHEN 'week'  THEN now() - interval '7 days'
      WHEN 'month' THEN now() - interval '30 days'
      ELSE 'epoch'::timestamptz
    END AS since
  ),
  raw AS (
    SELECT g.winner_id AS uid, NULLIF(trim(pp.display_name),'') AS dn,
           g.pot * (1 - g.commission_pct/100.0) AS won,
           COALESCE(g.finished_at, g.created_at) AS at
      FROM ludo_games g JOIN ludo_participants pp ON pp.game_id=g.id AND pp.user_id=g.winner_id, bound
      WHERE (_slug IS NULL OR _slug = 'all' OR _slug = 'ludo')
        AND g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at,g.created_at) >= bound.since
    UNION ALL
    SELECT g.winner_id, NULLIF(trim(pp.display_name),''),
           g.pot * (1 - COALESCE(g.commission_pct,0)/100.0),
           COALESCE(g.finished_at, g.created_at)
      FROM domino_games g JOIN domino_participants pp ON pp.game_id=g.id AND pp.user_id=g.winner_id, bound
      WHERE (_slug IS NULL OR _slug = 'all' OR _slug = 'domino')
        AND g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at,g.created_at) >= bound.since
    UNION ALL
    SELECT g.winner_id, NULLIF(trim(pp.display_name),''),
           g.pot * (1 - COALESCE(g.commission_pct,0)/100.0),
           COALESCE(g.finished_at, g.created_at)
      FROM fanorona_games g JOIN fanorona_participants pp ON pp.game_id=g.id AND pp.user_id=g.winner_id, bound
      WHERE (_slug IS NULL OR _slug = 'all' OR _slug = 'fanorona')
        AND g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at,g.created_at) >= bound.since
    UNION ALL
    SELECT g.winner_id, NULLIF(trim(pp.display_name),''),
           g.pot * (1 - COALESCE(g.commission_pct,0)/100.0),
           COALESCE(g.finished_at, g.created_at)
      FROM rami_games g JOIN rami_participants pp ON pp.game_id=g.id AND pp.user_id=g.winner_id, bound
      WHERE (_slug IS NULL OR _slug = 'all' OR _slug = 'rami')
        AND g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at,g.created_at) >= bound.since
    UNION ALL
    SELECT g.winner_id, NULL::text,
           g.stake * 2 * (1 - COALESCE((SELECT commission_pct FROM app_settings WHERE id=1),0)/100.0),
           COALESCE(g.finished_at, g.created_at)
      FROM chess_games g, bound
      WHERE (_slug IS NULL OR _slug = 'all' OR _slug = 'chess')
        AND g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at,g.created_at) >= bound.since
    UNION ALL
    SELECT g.winner_id, NULLIF(trim(pp.bot_name),''),
           g.pot * (1 - COALESCE(g.commission_pct,0)/100.0),
           COALESCE(g.finished_at, g.created_at)
      FROM poker_games g JOIN poker_players pp ON pp.game_id=g.id AND pp.user_id=g.winner_id, bound
      WHERE (_slug IS NULL OR _slug = 'all' OR _slug = 'poker')
        AND g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at,g.created_at) >= bound.since
  ),
  filtered AS (
    SELECT r.uid, r.dn, r.won, r.at FROM raw r
    WHERE (NOT public.has_role(r.uid, 'admin'::public.app_role)
           OR EXISTS (
                SELECT 1 FROM public.admin_persona ap
                WHERE ap.admin_id = r.uid AND ap.is_active
              ))
  ),
  named AS (
    SELECT f.uid, f.won, f.at,
           COALESCE(p.pseudo, f.dn, 'Joueur') AS display_name,
           p.avatar_url
    FROM filtered f LEFT JOIN public.profiles p ON p.id=f.uid
  ),
  agg AS (
    SELECT n.uid, count(*)::bigint AS wins, COALESCE(sum(n.won), 0)::numeric AS total_won
    FROM named n GROUP BY n.uid
  ),
  latest_name AS (
    SELECT DISTINCT ON (n.uid) n.uid, n.display_name, n.avatar_url
    FROM named n ORDER BY n.uid, n.at DESC
  )
  SELECT a.uid AS user_id, ln.display_name AS name, ln.avatar_url, a.wins, a.total_won,
         COALESCE(pr.leaderboard_hidden, false) AS hidden,
         pr.leaderboard_rank_override AS rank_override
  FROM agg a
  JOIN latest_name ln ON ln.uid = a.uid
  LEFT JOIN public.profiles pr ON pr.id = a.uid
  ORDER BY COALESCE(pr.leaderboard_rank_override, 2147483647) ASC, a.wins DESC, ln.display_name ASC
  LIMIT _limit;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_list_aliases()
 RETURNS TABLE(id uuid, pseudo text, avatar_url text, created_at timestamp with time zone, is_active boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  RETURN QUERY
    SELECT a.id, a.pseudo, a.avatar_url, a.created_at,
           COALESCE((SELECT p.is_active AND p.alias_id = a.id FROM public.admin_persona p WHERE p.admin_id = auth.uid()), false)
    FROM public.admin_aliases a
    WHERE a.admin_id = auth.uid()
    ORDER BY a.created_at DESC;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_list_all_active_sessions()
 RETURNS TABLE(id uuid, user_id uuid, admin_name text, ip inet, user_agent text, mfa_verified boolean, created_at timestamp with time zone, last_seen_at timestamp with time zone, expires_at timestamp with time zone, override_reason text, is_me boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT s.id, s.user_id,
         COALESCE(p.pseudo, p.phone, 'admin') AS admin_name,
         s.ip, s.user_agent, s.mfa_verified,
         s.created_at, s.last_seen_at, s.expires_at, s.override_reason,
         (s.user_id = auth.uid()) AS is_me
  FROM public.admin_sessions s
  LEFT JOIN public.profiles p ON p.id = s.user_id
  WHERE s.revoked_at IS NULL
    AND s.expires_at > now()
    AND public.has_role(auth.uid(), 'admin')
  ORDER BY s.last_seen_at DESC;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_list_bug_reports(_status text DEFAULT NULL::text, _limit integer DEFAULT 100)
 RETURNS TABLE(id uuid, user_id uuid, pseudo text, category text, message text, status text, admin_note text, created_at timestamp with time zone, resolved_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  RETURN QUERY
    SELECT br.id, br.user_id, COALESCE(p.pseudo, 'Joueur supprimé'),
           br.category, br.message, br.status, br.admin_note,
           br.created_at, br.resolved_at
    FROM public.bug_reports br
    LEFT JOIN public.profiles p ON p.id = br.user_id
    WHERE (_status IS NULL OR br.status = _status)
    ORDER BY br.created_at DESC
    LIMIT _limit;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_list_games()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', g.id, 'status', g.status, 'stake', g.stake, 'pot', g.pot,
    'max_players', g.max_players, 'created_at', g.created_at,
    'is_private', g.is_private, 'host_id', g.host_id,
    'players', (SELECT jsonb_agg(jsonb_build_object('user_id',p.user_id,'name',p.display_name,'forfeited',p.forfeited,'is_bot',p.is_bot)) FROM public.ludo_participants p WHERE p.game_id=g.id)
  ) ORDER BY g.created_at DESC), '[]'::jsonb)
  FROM public.ludo_games g
  WHERE g.status IN ('open','playing')
    AND public.is_admin()
$function$
;

CREATE OR REPLACE FUNCTION public.admin_list_my_sessions()
 RETURNS TABLE(id uuid, ip inet, user_agent text, mfa_verified boolean, created_at timestamp with time zone, last_seen_at timestamp with time zone, expires_at timestamp with time zone, revoked_at timestamp with time zone, revoke_reason text, override_reason text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT id, ip, user_agent, mfa_verified,
         created_at, last_seen_at, expires_at,
         revoked_at, revoke_reason, override_reason
  FROM public.admin_sessions
  WHERE user_id = auth.uid()
  ORDER BY created_at DESC
  LIMIT 50;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_list_phone_requests()
 RETURNS TABLE(id uuid, pseudo text, phone text, code text, requested_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  RETURN QUERY
    SELECT p.id, p.pseudo, p.phone, p.phone_verification_code, p.phone_verification_requested_at
    FROM public.profiles p
    WHERE p.phone IS NOT NULL AND p.phone_verified = false AND p.phone_verification_code IS NOT NULL
    ORDER BY p.phone_verification_requested_at DESC;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_list_users()
 RETURNS TABLE(id uuid, pseudo text, email text, balance_ar numeric, created_at timestamp with time zone, is_admin boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  RETURN QUERY SELECT p.id, p.pseudo, p.email, p.balance_ar, p.created_at,
    EXISTS(SELECT 1 FROM public.user_roles r WHERE r.user_id=p.id AND r.role='admin')
    FROM public.profiles p ORDER BY p.created_at DESC;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_list_users_sorted(_sort text)
 RETURNS TABLE(id uuid, pseudo text, email text, balance_ar numeric, created_at timestamp with time zone, is_admin boolean, phone_verified boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  RETURN QUERY
    SELECT p.id, p.pseudo, p.email, p.balance_ar, p.created_at,
      EXISTS(SELECT 1 FROM public.user_roles r WHERE r.user_id=p.id AND r.role='admin'),
      p.phone_verified
    FROM public.profiles p
    ORDER BY
      CASE WHEN _sort='balance' THEN p.balance_ar END DESC NULLS LAST,
      CASE WHEN _sort='pseudo' THEN p.pseudo END ASC,
      CASE WHEN _sort='recent' OR _sort IS NULL OR _sort='' THEN p.created_at END DESC;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_manual_payout(_uid uuid, _amount numeric, _reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_admin uuid := auth.uid();
  v_amount numeric := COALESCE(_amount, 0);
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;
  IF v_amount <= 0 THEN RAISE EXCEPTION 'Montant invalide'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = _uid) THEN
    RAISE EXCEPTION 'Joueur introuvable';
  END IF;

  UPDATE public.profiles
    SET balance_ar = balance_ar + v_amount
    WHERE id = _uid;

  INSERT INTO public.transactions(user_id, type, amount, note)
    VALUES (_uid, 'admin_payout', v_amount, COALESCE(NULLIF(_reason, ''), 'Paiement manuel admin'));

  INSERT INTO public.admin_logs(admin_id, action, target_user_id, new_value)
    VALUES (v_admin, 'admin_manual_payout', _uid,
      jsonb_build_object('amount', v_amount, 'reason', _reason));

  INSERT INTO public.notifications(user_id, kind, title, body)
    VALUES (_uid, 'payment', 'Paiement admin reçu', v_amount::text || ' Ar — ' || COALESCE(_reason, 'Correction'));

  RETURN jsonb_build_object('ok', true, 'amount', v_amount);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_offer_delete(_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin'::public.app_role) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  DELETE FROM public.money_offers WHERE id = _id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_offer_upsert(_id uuid, _title text, _description text, _image_url text, _link text, _expires_at timestamp with time zone, _active boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id UUID;
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin'::public.app_role) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF _id IS NULL THEN
    INSERT INTO public.money_offers (title, description, image_url, link, expires_at, active)
    VALUES (_title, _description, _image_url, _link, _expires_at, COALESCE(_active, true))
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.money_offers
       SET title = _title,
           description = _description,
           image_url = _image_url,
           link = _link,
           expires_at = _expires_at,
           active = COALESCE(_active, active),
           updated_at = now()
     WHERE id = _id
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_override_login(_reason text, _ip inet, _user_agent text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _me uuid := auth.uid();
  _req_id uuid;
BEGIN
  IF _me IS NULL OR NOT public.has_role(_me, 'admin') THEN
    RAISE EXCEPTION 'Not admin';
  END IF;
  IF _reason IS NULL OR length(trim(_reason)) < 10 THEN
    RAISE EXCEPTION 'Motif obligatoire (10 caractères minimum)';
  END IF;

  INSERT INTO public.admin_login_approvals(
    requesting_user_id, requesting_ip, requesting_user_agent,
    status, override_reason, decided_at
  ) VALUES (_me, _ip, _user_agent, 'override', _reason, now())
  RETURNING id INTO _req_id;

  PERFORM public._admin_notify_others(
    'admin_login_override',
    jsonb_build_object('request_id', _req_id, 'requester', _me, 'reason', _reason,
                       'ip', _ip::text, 'ua', _user_agent)
  );

  RETURN jsonb_build_object('status', 'override', 'request_id', _req_id);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_override_match_winner(_mid uuid, _winner_id uuid, _reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_match record;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  SELECT * INTO v_match FROM public.tournament_matches WHERE id = _mid FOR UPDATE;
  IF v_match IS NULL THEN RAISE EXCEPTION 'Match introuvable'; END IF;
  IF NOT (_winner_id = ANY(v_match.player_ids)) THEN RAISE EXCEPTION 'Le vainqueur doit être un joueur du match'; END IF;

  UPDATE public.tournament_matches
    SET status = 'finished',
        winner_id = _winner_id,
        finished_at = now(),
        admin_notes = COALESCE(admin_notes || ' | ', '') || 'Vainqueur modifié: ' || COALESCE(NULLIF(_reason, ''), 'Sans raison')
    WHERE id = _mid;

  INSERT INTO public.admin_logs(admin_id, action, target_user_id, old_value, new_value)
    VALUES (v_uid, 'admin_override_match_winner', _winner_id,
      jsonb_build_object('match_id', _mid, 'previous_status', v_match.status, 'previous_winner_id', v_match.winner_id),
      jsonb_build_object('match_id', _mid, 'winner_id', _winner_id, 'reason', _reason));

  INSERT INTO public.notifications(user_id, kind, title, body, link, ref_id)
    VALUES (_winner_id, 'tournament', 'Résultat du match mis à jour', COALESCE(_reason, 'Décision administrateur'), '/tournaments/' || v_match.tournament_id::text, _mid);

  RETURN jsonb_build_object('ok', true, 'winner_id', _winner_id);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_permanently_delete_user(_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin'::public.app_role) THEN RAISE EXCEPTION 'Accès refusé'; END IF;
  IF _user_id = auth.uid() THEN RAISE EXCEPTION 'Impossible de supprimer votre propre compte'; END IF;
  BEGIN UPDATE public.ludo_games     SET winner_id = NULL WHERE winner_id = _user_id; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN UPDATE public.domino_games   SET winner_id = NULL WHERE winner_id = _user_id; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN UPDATE public.fanorona_games SET winner_id = NULL WHERE winner_id = _user_id; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN UPDATE public.rami_games     SET winner_id = NULL WHERE winner_id = _user_id; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN UPDATE public.chess_games    SET winner_id = NULL WHERE winner_id = _user_id; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN UPDATE public.chess_games    SET white_id  = NULL WHERE white_id  = _user_id; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN UPDATE public.chess_games    SET black_id  = NULL WHERE black_id  = _user_id; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN UPDATE public.profiles       SET referred_by = NULL WHERE referred_by = _user_id; EXCEPTION WHEN OTHERS THEN NULL; END;
  DELETE FROM auth.users WHERE id = _user_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_process_deposit(_id uuid, _approve boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_dep public.deposits%ROWTYPE;
  v_debt NUMERIC;
  v_repay NUMERIC;
  v_credit NUMERIC;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  SELECT * INTO v_dep FROM public.deposits WHERE id=_id FOR UPDATE;
  IF v_dep.id IS NULL OR v_dep.status <> 'pending' THEN RAISE EXCEPTION 'Dépôt non valide'; END IF;

  IF _approve THEN
    UPDATE public.deposits SET status='approved', processed_at=now() WHERE id=_id;

    -- Check outstanding debt
    SELECT amount_ar INTO v_debt FROM public.withdrawal_debts WHERE user_id = v_dep.user_id FOR UPDATE;
    v_debt := COALESCE(v_debt, 0);
    v_repay := LEAST(v_debt, v_dep.amount);
    v_credit := v_dep.amount - v_repay;

    -- Full deposit transaction (transparent)
    INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
      VALUES (v_dep.user_id,'deposit',v_dep.amount,_id,'Dépôt approuvé');

    IF v_repay > 0 THEN
      UPDATE public.withdrawal_debts
        SET amount_ar = amount_ar - v_repay, updated_at = now()
        WHERE user_id = v_dep.user_id;
      DELETE FROM public.withdrawal_debts WHERE user_id = v_dep.user_id AND amount_ar <= 0;
      INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
        VALUES (v_dep.user_id,'debt_repayment', -v_repay, _id,
          format('Remboursement automatique de retrait antérieur (%s Ar)', to_char(v_repay,'FM999G999G999')));
    END IF;

    IF v_credit > 0 THEN
      UPDATE public.profiles SET balance_ar = balance_ar + v_credit WHERE id = v_dep.user_id;
    END IF;

    INSERT INTO public.notifications(user_id, kind, title, body, link, ref_id)
    VALUES (v_dep.user_id, 'deposit',
      'Dépôt approuvé ✅',
      CASE WHEN v_repay > 0 THEN
        format('Dépôt de %s Ar approuvé. %s Ar utilisés pour régler un retrait antérieur, %s Ar crédités.',
          to_char(v_dep.amount,'FM999G999G999'),
          to_char(v_repay,'FM999G999G999'),
          to_char(v_credit,'FM999G999G999'))
      ELSE
        format('Votre dépôt de %s Ar a été crédité sur votre solde.', to_char(v_dep.amount,'FM999G999G999'))
      END,
      '/history', _id);
  ELSE
    UPDATE public.deposits SET status='rejected', processed_at=now() WHERE id=_id;
    INSERT INTO public.notifications(user_id, kind, title, body, link, ref_id)
    VALUES (v_dep.user_id, 'deposit',
      'Dépôt refusé ❌',
      format('Votre dépôt de %s Ar a été refusé.', to_char(v_dep.amount,'FM999G999G999')),
      '/history', _id);
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_process_withdrawal(_id uuid, _approve boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_w public.withdrawals%ROWTYPE;
  v_balance numeric;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  SELECT * INTO v_w FROM public.withdrawals WHERE id=_id FOR UPDATE;
  IF v_w.id IS NULL OR v_w.status <> 'pending' THEN RAISE EXCEPTION 'Retrait non valide'; END IF;

  IF _approve THEN
    SELECT balance_ar INTO v_balance FROM public.profiles WHERE id = v_w.user_id FOR UPDATE;
    IF v_balance IS NULL THEN RAISE EXCEPTION 'Profil introuvable'; END IF;
    IF v_balance < v_w.amount THEN
      RAISE EXCEPTION 'Solde insuffisant (solde: % Ar, demandé: % Ar)', v_balance, v_w.amount;
    END IF;

    -- Débit uniquement du montant demandé
    UPDATE public.profiles SET balance_ar = balance_ar - v_w.amount WHERE id = v_w.user_id;
    UPDATE public.withdrawals SET status='approved', processed_at=now() WHERE id=_id;

    INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
      VALUES (v_w.user_id,'withdraw',-v_w.amount,_id,'Retrait approuvé');

    INSERT INTO public.notifications(user_id, kind, title, body, link, ref_id)
    VALUES (v_w.user_id, 'withdraw',
      'Retrait approuvé ✅',
      format('Votre retrait de %s Ar a été validé.', to_char(v_w.amount,'FM999G999G999')),
      '/history', _id);
  ELSE
    UPDATE public.withdrawals SET status='rejected', processed_at=now() WHERE id=_id;
    INSERT INTO public.notifications(user_id, kind, title, body, link, ref_id)
    VALUES (v_w.user_id, 'withdraw',
      'Retrait refusé ❌',
      format('Votre retrait de %s Ar a été refusé.', to_char(v_w.amount,'FM999G999G999')),
      '/history', _id);
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_reconcile_balances()
 RETURNS TABLE(user_id uuid, pseudo text, balance numeric, tx_sum numeric, diff numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin'::app_role) THEN RAISE EXCEPTION 'Forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.pseudo, p.balance_ar::numeric,
         COALESCE((SELECT SUM(amount) FROM public.transactions WHERE user_id = p.id),0)::numeric AS tx_sum,
         (p.balance_ar - COALESCE((SELECT SUM(amount) FROM public.transactions WHERE user_id = p.id),0))::numeric AS diff
  FROM public.profiles p
  WHERE COALESCE(p.is_bot,false) = false
    AND (p.balance_ar - COALESCE((SELECT SUM(amount) FROM public.transactions WHERE user_id = p.id),0)) <> 0
  ORDER BY ABS(p.balance_ar - COALESCE((SELECT SUM(amount) FROM public.transactions WHERE user_id = p.id),0)) DESC;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_record_login_attempt(_user_id uuid, _success boolean, _reason text, _ip inet, _ua text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _recent_fails int;
  _lock_until timestamptz;
BEGIN
  INSERT INTO public.admin_login_attempts(user_id, success, reason, ip, user_agent)
  VALUES (_user_id, _success, _reason, _ip, _ua);

  IF _success THEN
    DELETE FROM public.admin_lockouts WHERE user_id = _user_id;
    RETURN jsonb_build_object('locked', false);
  END IF;

  IF _user_id IS NULL OR NOT public.has_role(_user_id, 'admin') THEN
    RETURN jsonb_build_object('locked', false, 'admin', false);
  END IF;

  SELECT count(*) INTO _recent_fails
  FROM public.admin_login_attempts
  WHERE user_id = _user_id
    AND success = false
    AND created_at > now() - interval '30 minutes';

  -- Assoupli : 10 échecs / 30min → blocage 10 min
  IF _recent_fails >= 10 THEN
    _lock_until := now() + interval '10 minutes';
    INSERT INTO public.admin_lockouts(user_id, locked_until, reason, fail_count)
    VALUES (_user_id, _lock_until, 'Trop de tentatives échouées (10 en 30 min)', _recent_fails)
    ON CONFLICT (user_id) DO UPDATE
      SET locked_until = EXCLUDED.locked_until,
          reason = EXCLUDED.reason,
          fail_count = EXCLUDED.fail_count,
          updated_at = now();

    PERFORM public._admin_notify_others(
      'admin_locked_out',
      jsonb_build_object('user_id', _user_id, 'until', _lock_until, 'ip', _ip::text, 'ua', _ua)
    );

    RETURN jsonb_build_object('locked', true, 'until', _lock_until);
  END IF;

  RETURN jsonb_build_object('locked', false, 'fails', _recent_fails);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_refund_game(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g public.ludo_games%ROWTYPE; p RECORD;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  SELECT * INTO g FROM public.ludo_games WHERE id=_game_id;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  FOR p IN SELECT user_id FROM public.ludo_participants
           WHERE game_id=_game_id AND user_id IS NOT NULL AND is_bot=false
  LOOP
    UPDATE public.profiles SET balance_ar = balance_ar + g.stake WHERE id=p.user_id;
    INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
      VALUES (p.user_id,'refund',g.stake,g.id,'Remboursement admin');
  END LOOP;
  INSERT INTO public.admin_logs(admin_id, action) VALUES (auth.uid(),'admin_refund_game');
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_reply_support(_id uuid, _reply text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  UPDATE public.support_messages SET reply=_reply, status='answered' WHERE id=_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_request_login_approval(_ip inet, _user_agent text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _me uuid := auth.uid();
  _req_id uuid;
BEGIN
  IF _me IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF NOT public.has_role(_me, 'admin') THEN
    RAISE EXCEPTION 'Not admin';
  END IF;

  -- If no other admin session is active, auto-approve
  IF NOT public._admin_has_active_session(_me) THEN
    RETURN jsonb_build_object('status', 'auto_approved', 'requires_approval', false);
  END IF;

  -- Otherwise create pending approval
  INSERT INTO public.admin_login_approvals(requesting_user_id, requesting_ip, requesting_user_agent)
  VALUES (_me, _ip, _user_agent)
  RETURNING id INTO _req_id;

  PERFORM public._admin_notify_others(
    'admin_login_approval_requested',
    jsonb_build_object('request_id', _req_id, 'requester', _me, 'ip', _ip::text, 'ua', _user_agent)
  );

  RETURN jsonb_build_object('status', 'pending', 'requires_approval', true, 'request_id', _req_id);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_reset_all_terms()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_n integer;
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin') THEN RAISE EXCEPTION 'Forbidden'; END IF;
  UPDATE public.profiles SET terms_accepted_at = NULL WHERE terms_accepted_at IS NOT NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_resolve_claim(_cid uuid, _status text, _comment text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_admin uuid := auth.uid();
  v_claim record;
  v_status text := lower(COALESCE(_status, ''));
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;
  IF v_status NOT IN ('pending','reviewing','resolved','rejected') THEN
    RAISE EXCEPTION 'Statut invalide';
  END IF;

  SELECT * INTO v_claim FROM public.tournament_claims WHERE id = _cid FOR UPDATE;
  IF v_claim IS NULL THEN RAISE EXCEPTION 'Réclamation introuvable'; END IF;

  UPDATE public.tournament_claims
    SET status = v_status,
        resolution_note = CASE WHEN v_status IN ('resolved','rejected') THEN COALESCE(_comment, resolution_note) ELSE COALESCE(_comment, resolution_note) END,
        resolved_by = CASE WHEN v_status IN ('resolved','rejected') THEN v_admin ELSE resolved_by END,
        resolved_at = CASE WHEN v_status IN ('resolved','rejected') THEN now() ELSE resolved_at END
    WHERE id = _cid;

  INSERT INTO public.admin_logs(admin_id, action, target_id, target_user_id, old_value, new_value)
    VALUES (v_admin, 'admin_resolve_claim', _cid, v_claim.claimant_id,
      jsonb_build_object('previous_status', v_claim.status),
      jsonb_build_object('status', v_status, 'comment', _comment));

  INSERT INTO public.notifications(user_id, kind, title, body, link, ref_id)
    VALUES (v_claim.claimant_id, 'tournament',
      CASE
        WHEN v_status = 'reviewing' THEN 'Réclamation en analyse'
        WHEN v_status = 'resolved' THEN 'Réclamation résolue'
        WHEN v_status = 'rejected' THEN 'Réclamation rejetée'
        ELSE 'Réclamation mise à jour'
      END,
      COALESCE(_comment, 'Votre réclamation a été mise à jour.'),
      '/tournaments/' || v_claim.tournament_id::text,
      _cid);

  RETURN jsonb_build_object('ok', true, 'status', v_status);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_resolve_fraud_flag(_flag_id uuid, _resolution text, _pay_anyway boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_flag public.referral_fraud_flags%ROWTYPE;
  v_reward numeric; v_pct numeric;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Accès refusé'; END IF;
  SELECT * INTO v_flag FROM public.referral_fraud_flags WHERE id = _flag_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Flag introuvable'; END IF;
  UPDATE public.referral_fraud_flags
    SET status = _resolution, reviewed_by = auth.uid(), reviewed_at = now()
    WHERE id = _flag_id;
  IF _pay_anyway AND _resolution = 'cleared' AND v_flag.referrer_id IS NOT NULL THEN
    SELECT deposit_bonus_pct INTO v_pct FROM public.referral_settings WHERE id=1;
    SELECT amount INTO v_reward FROM public.deposits WHERE id = (v_flag.details->>'deposit_id')::uuid;
    IF v_reward IS NOT NULL THEN
      v_reward := ROUND(v_reward * v_pct / 100.0, 0);
      UPDATE public.profiles SET balance_ar = balance_ar + v_reward WHERE id = v_flag.referrer_id;
      UPDATE public.profiles SET referral_unlocked = true WHERE id = v_flag.referee_id;
      BEGIN
        INSERT INTO public.transactions(user_id, type, amount, note)
        VALUES(v_flag.referrer_id,'referral',v_reward,'Parrainage validé manuellement par admin');
      EXCEPTION WHEN OTHERS THEN NULL; END;
      INSERT INTO public.referral_events(referrer_id,referee_id,event_type,reward_amount,note)
      VALUES(v_flag.referrer_id,v_flag.referee_id,'first_deposit',v_reward,'Validé manuellement')
      ON CONFLICT(referee_id,event_type) DO NOTHING;
    END IF;
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_respond_login_approval(_request_id uuid, _decision text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _me uuid := auth.uid();
  _rec public.admin_login_approvals;
BEGIN
  IF _me IS NULL OR NOT public.has_role(_me, 'admin') THEN
    RAISE EXCEPTION 'Not admin';
  END IF;
  IF _decision NOT IN ('approved','denied') THEN
    RAISE EXCEPTION 'Invalid decision';
  END IF;

  SELECT * INTO _rec FROM public.admin_login_approvals WHERE id = _request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Not found'; END IF;
  IF _rec.status <> 'pending' THEN
    RETURN jsonb_build_object('status', _rec.status, 'already_decided', true);
  END IF;
  IF _rec.expires_at <= now() THEN
    UPDATE public.admin_login_approvals SET status='expired', decided_at=now() WHERE id=_request_id;
    RETURN jsonb_build_object('status', 'expired');
  END IF;
  IF _rec.requesting_user_id = _me THEN
    RAISE EXCEPTION 'Cannot approve your own request';
  END IF;

  UPDATE public.admin_login_approvals
     SET status = _decision, approver_user_id = _me, decided_at = now()
   WHERE id = _request_id;

  PERFORM public._admin_notify_others(
    'admin_login_' || _decision,
    jsonb_build_object('request_id', _request_id, 'requester', _rec.requesting_user_id, 'approver', _me)
  );

  RETURN jsonb_build_object('status', _decision);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_revoke_all_other_sessions()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE _me uuid := auth.uid(); _n int;
BEGIN
  IF _me IS NULL OR NOT public.has_role(_me, 'admin') THEN
    RAISE EXCEPTION 'Not admin';
  END IF;
  WITH upd AS (
    UPDATE public.admin_sessions
       SET revoked_at = now(), revoke_reason = 'revoked_by_self_all_other'
     WHERE user_id = _me AND revoked_at IS NULL
     RETURNING 1
  ) SELECT count(*) INTO _n FROM upd;
  RETURN COALESCE(_n, 0);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_revoke_any_session(_session_id uuid, _reason text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE _me uuid := auth.uid(); _target_user uuid;
BEGIN
  IF _me IS NULL OR NOT public.has_role(_me, 'admin') THEN
    RAISE EXCEPTION 'Not admin';
  END IF;

  UPDATE public.admin_sessions
     SET revoked_at = now(),
         revoke_reason = COALESCE(_reason, 'révoquée par un autre admin')
   WHERE id = _session_id AND revoked_at IS NULL
   RETURNING user_id INTO _target_user;

  IF _target_user IS NULL THEN RETURN false; END IF;

  PERFORM public._admin_notify_others(
    'admin_session_revoked_by_peer',
    jsonb_build_object('session_id', _session_id, 'target_user', _target_user, 'by', _me, 'reason', _reason)
  );
  RETURN true;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_revoke_session(_session_id uuid, _reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE _me uuid := auth.uid(); _target uuid;
BEGIN
  IF _me IS NULL OR NOT public.has_role(_me, 'admin') THEN
    RAISE EXCEPTION 'Not admin';
  END IF;

  SELECT user_id INTO _target FROM public.admin_sessions WHERE id = _session_id;
  IF _target IS NULL THEN RAISE EXCEPTION 'Not found'; END IF;
  -- self, or any admin can revoke
  UPDATE public.admin_sessions
     SET revoked_at = now(), revoke_reason = COALESCE(_reason, 'manual')
   WHERE id = _session_id AND revoked_at IS NULL;

  IF _target <> _me THEN
    PERFORM public._admin_notify_others(
      'admin_session_revoked_by_peer',
      jsonb_build_object('session_id', _session_id, 'target', _target, 'by', _me, 'reason', _reason)
    );
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_save_alias(p_pseudo text, p_avatar_url text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_id UUID;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  INSERT INTO public.admin_aliases(admin_id, pseudo, avatar_url)
    VALUES (auth.uid(), p_pseudo, p_avatar_url) RETURNING id INTO v_id;
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_search_users(_q text)
 RETURNS TABLE(id uuid, pseudo text, email text, balance_ar numeric, unique_code text, banned boolean, status text, created_at timestamp with time zone, is_admin boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  RETURN QUERY
    SELECT p.id, p.pseudo, p.email, p.balance_ar, p.unique_code, p.banned, p.status, p.created_at,
      EXISTS(SELECT 1 FROM public.user_roles r WHERE r.user_id=p.id AND r.role='admin')
    FROM public.profiles p
    WHERE _q IS NULL OR _q = '' OR
      p.pseudo ILIKE '%'||_q||'%' OR p.email ILIKE '%'||_q||'%' OR p.unique_code ILIKE '%'||_q||'%' OR p.id::text = _q
    ORDER BY p.created_at DESC LIMIT 100;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_send_email_otp()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _me uuid := auth.uid();
  _code text;
  _hash text;
  _email text;
BEGIN
  IF _me IS NULL OR NOT public.has_role(_me, 'admin') THEN
    RAISE EXCEPTION 'Not admin';
  END IF;

  -- rate limit: max 3 codes / 10 min
  IF (SELECT count(*) FROM public.admin_email_otps
      WHERE user_id = _me AND created_at > now() - interval '10 minutes') >= 3 THEN
    RAISE EXCEPTION 'Trop de codes demandés. Réessayez dans 10 min.';
  END IF;

  SELECT email INTO _email FROM auth.users WHERE id = _me;
  IF _email IS NULL THEN RAISE EXCEPTION 'Aucune e-mail associée au compte'; END IF;

  _code := lpad((floor(random() * 1000000))::int::text, 6, '0');
  _hash := encode(extensions.digest(_code, 'sha256'), 'hex');

  INSERT INTO public.admin_email_otps(user_id, code_hash) VALUES (_me, _hash);

  -- Try enqueue via existing email infra (silent fallback)
  BEGIN
    PERFORM public.enqueue_email(
      _email,
      '🔐 Code de secours admin — Lalao MADA',
      '<p>Votre code de secours admin est :</p><h1 style="font-size:32px;letter-spacing:8px;text-align:center;">' || _code || '</h1><p>Valide 10 minutes. Ne le partagez jamais.</p>'
    );
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN jsonb_build_object('sent', true);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_set_daily_bonus(_enabled boolean, _amount_ar integer, _streak_bonus boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin'::public.app_role) THEN RAISE EXCEPTION 'Accès refusé'; END IF;
  UPDATE public.app_settings SET
    daily_bonus_enabled       = _enabled,
    daily_bonus_amount_ar     = _amount_ar,
    daily_bonus_streak_bonus  = _streak_bonus
  WHERE id = 1;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_set_forfeit_cron_interval(_seconds integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_sched text;
BEGIN
  IF NOT public.has_role(auth.uid(),'admin') THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;
  IF _seconds < 10 OR _seconds > 600 THEN
    RAISE EXCEPTION 'La fréquence doit être entre 10 et 600 secondes';
  END IF;

  v_sched := _seconds || ' seconds';

  -- Recréer le job
  PERFORM cron.unschedule('tournament_auto_forfeit')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'tournament_auto_forfeit');

  PERFORM cron.schedule('tournament_auto_forfeit', v_sched,
    $c$SELECT public.tournament_auto_forfeit_expired();$c$);

  INSERT INTO public.admin_action_logs(admin_id, action, meta)
    VALUES (auth.uid(), 'set_forfeit_cron_interval',
            jsonb_build_object('seconds', _seconds));

  RETURN jsonb_build_object('ok', true, 'schedule', v_sched);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_set_leaderboard_hidden(_user_id uuid, _hidden boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'not authorized'; END IF;
  UPDATE public.profiles SET leaderboard_hidden = _hidden WHERE id = _user_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_set_leaderboard_rank(_user_id uuid, _rank integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'not authorized'; END IF;
  UPDATE public.profiles SET leaderboard_rank_override = _rank WHERE id = _user_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_set_pause(_paused boolean, _message text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  UPDATE public.app_settings SET paused=_paused, pause_message=_message, updated_at=now() WHERE id=1;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_set_reward_distribution(_tid uuid, _first_pct numeric, _second_pct numeric, _third_pct numeric, _platform_pct numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _sum numeric;
  _p record;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;

  _sum := COALESCE(_first_pct,0) + COALESCE(_second_pct,0) + COALESCE(_third_pct,0) + COALESCE(_platform_pct,0);
  IF ROUND(_sum::numeric, 2) <> 100 THEN
    RAISE EXCEPTION 'La somme des pourcentages doit être 100 (actuel: %)', _sum;
  END IF;

  UPDATE public.tournaments
  SET reward_distribution = jsonb_build_object(
        'first', _first_pct,
        'second', _second_pct,
        'third', _third_pct,
        'platform', _platform_pct
      ),
      updated_at = now()
  WHERE id = _tid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tournoi introuvable';
  END IF;

  -- Notifier les joueurs inscrits
  FOR _p IN SELECT user_id FROM public.tournament_registrations WHERE tournament_id = _tid LOOP
    BEGIN
      INSERT INTO public.notifications (user_id, type, title, message, data)
      VALUES (
        _p.user_id,
        'tournament_update',
        'Répartition des gains mise à jour',
        format('1er: %s%% • 2e: %s%% • 3e: %s%% • Plateforme: %s%%',
               _first_pct, _second_pct, _third_pct, _platform_pct),
        jsonb_build_object('tournament_id', _tid)
      );
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;

  BEGIN
    INSERT INTO public.admin_action_logs (admin_id, action, target_type, target_id, details)
    VALUES (auth.uid(), 'set_reward_distribution', 'tournament', _tid,
            jsonb_build_object('first',_first_pct,'second',_second_pct,'third',_third_pct,'platform',_platform_pct));
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_set_user_banned(_user_id uuid, _banned boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_old boolean;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  SELECT banned INTO v_old FROM public.profiles WHERE id=_user_id;
  UPDATE public.profiles SET banned=_banned WHERE id=_user_id;
  PERFORM public._admin_log(_user_id,'set_banned',to_jsonb(v_old),to_jsonb(_banned));
END $function$
;

-- ═══════════ 0007_functions_07.sql ═══════════
-- 0007_functions_07.sql
-- Fonctions et procédures (7/12)

CREATE OR REPLACE FUNCTION public.admin_set_user_status(_user_id uuid, _status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_old text;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  SELECT status INTO v_old FROM public.profiles WHERE id=_user_id;
  UPDATE public.profiles SET status=_status WHERE id=_user_id;
  PERFORM public._admin_log(_user_id,'set_status',to_jsonb(v_old),to_jsonb(_status));
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_stats_daily(_days integer)
 RETURNS TABLE(day date, deposits numeric, withdrawals numeric, wins numeric, commission numeric, stakes numeric, new_users bigint, active_users bigint, games_finished bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (current_date - (_days-1) * interval '1 day')::date,
      current_date::date,
      interval '1 day'
    )::date AS d
  ),
  games_all AS (
    SELECT finished_at, pot, commission_pct FROM public.ludo_games WHERE status='finished'
    UNION ALL SELECT finished_at, pot, commission_pct FROM public.domino_games WHERE status='finished'
    UNION ALL SELECT finished_at, pot, commission_pct FROM public.chess_games WHERE status='finished'
    UNION ALL SELECT finished_at, pot, commission_pct FROM public.fanorona_games WHERE status='finished'
    UNION ALL SELECT finished_at, pot, commission_pct FROM public.rami_games WHERE status='finished'
  )
  SELECT d.d,
    COALESCE((SELECT SUM(amount) FROM public.deposits WHERE status='approved' AND processed_at::date = d.d),0)::numeric,
    COALESCE((SELECT SUM(amount) FROM public.withdrawals WHERE status='approved' AND processed_at::date = d.d),0)::numeric,
    COALESCE((SELECT SUM(amount) FROM public.transactions WHERE type='win' AND created_at::date = d.d),0)::numeric,
    COALESCE((SELECT SUM(pot * commission_pct / 100.0) FROM games_all WHERE finished_at::date = d.d),0)::numeric,
    COALESCE((SELECT SUM(-amount) FROM public.transactions WHERE type='stake' AND created_at::date = d.d),0)::numeric,
    COALESCE((SELECT COUNT(*) FROM public.profiles WHERE created_at::date = d.d),0)::bigint,
    COALESCE((SELECT COUNT(DISTINCT user_id) FROM public.transactions WHERE created_at::date = d.d),0)::bigint,
    COALESCE((SELECT COUNT(*) FROM games_all WHERE finished_at::date = d.d),0)::bigint
  FROM days d ORDER BY d.d DESC;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_suspend_player(_uid uuid, _hours integer, _reason text, _add_warning boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_admin uuid := auth.uid();
  v_until timestamptz;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = _uid) THEN
    RAISE EXCEPTION 'Joueur introuvable';
  END IF;

  IF COALESCE(_hours, 0) > 0 THEN
    v_until := now() + (GREATEST(_hours, 1)::text || ' hours')::interval;
    UPDATE public.profiles
      SET suspended_until = v_until,
          suspension_reason = COALESCE(NULLIF(_reason, ''), 'Décision administrateur'),
          warning_count = warning_count + CASE WHEN COALESCE(_add_warning, true) THEN 1 ELSE 0 END
      WHERE id = _uid;
  ELSE
    UPDATE public.profiles
      SET suspended_until = NULL,
          suspension_reason = NULL
      WHERE id = _uid;
  END IF;

  INSERT INTO public.admin_logs(admin_id, action, target_user_id, new_value)
    VALUES (v_admin, 'admin_suspend_player', _uid,
      jsonb_build_object('hours', COALESCE(_hours, 0), 'until', v_until, 'reason', _reason, 'warning', COALESCE(_add_warning, true)));

  INSERT INTO public.notifications(user_id, kind, title, body)
    VALUES (_uid,
      CASE WHEN COALESCE(_hours, 0) > 0 THEN 'warning' ELSE 'info' END,
      CASE WHEN COALESCE(_hours, 0) > 0 THEN 'Compte suspendu temporairement' ELSE 'Suspension levée' END,
      COALESCE(_reason, 'Décision administrateur'));

  RETURN jsonb_build_object('ok', true, 'suspended_until', v_until);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_top_referrers()
 RETURNS TABLE(referrer_id uuid, pseudo text, referral_code text, phone text, referral_count bigint, total_earned numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.pseudo,
    p.referral_code,
    p.phone,
    (SELECT COUNT(*) FROM public.profiles f WHERE f.referred_by = p.id)::bigint,
    COALESCE((SELECT SUM(e.reward_amount) FROM public.referral_events e WHERE e.referrer_id = p.id), 0)::numeric
  FROM public.profiles p
  WHERE EXISTS (SELECT 1 FROM public.profiles f WHERE f.referred_by = p.id)
  ORDER BY total_earned DESC NULLS LAST, referral_count DESC
  LIMIT 100;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_tournament_add_bots(_tid uuid, _count integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE i int; v_n int;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin uniquement'; END IF;
  SELECT count(*) INTO v_n FROM public.tournament_entrants WHERE tournament_id = _tid;
  FOR i IN 1.._count LOOP
    INSERT INTO public.tournament_entrants(tournament_id, display_name, is_bot)
      VALUES (_tid, 'Bot ' || (v_n + i), true);
  END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_tournament_cancel(_tid uuid, _reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE t public.tournaments%ROWTYPE; r record;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin uniquement'; END IF;
  SELECT * INTO t FROM public.tournaments WHERE id = _tid FOR UPDATE;
  IF t.status IN ('finished','cancelled') THEN RETURN; END IF;
  IF t.entry_fee_ar > 0 THEN
    FOR r IN SELECT * FROM public.tournament_entrants
              WHERE tournament_id = _tid AND user_id IS NOT NULL AND NOT is_bot LOOP
      PERFORM public.credit_user_balance(r.user_id, t.entry_fee_ar, 'tournament_refund', _tid,
        'Tournoi annulé: ' || t.name, '{}'::jsonb);
      PERFORM public._t_notify(r.id, '⚠️ Tournoi annulé',
        COALESCE(_reason, 'Votre inscription a été remboursée.'), '/tournaments');
    END LOOP;
  END IF;
  UPDATE public.tournament_matches SET status = 'cancelled'
   WHERE tournament_id = _tid AND status IN ('scheduled','running');
  UPDATE public.tournaments SET status = 'cancelled', finished_at = now() WHERE id = _tid;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_tournament_create(_name text, _game_slug text, _format text, _players_per_match integer, _max_players integer, _entry_fee_ar numeric, _admin_prize_pool_ar numeric, _winners_count integer, _p1 numeric, _p2 numeric, _p3 numeric, _pool_size integer DEFAULT 4, _qualifiers_per_pool integer DEFAULT 2, _max_concurrent integer DEFAULT 8, _lobby_minutes integer DEFAULT 5, _description text DEFAULT NULL::text, _registration_closes_at timestamp with time zone DEFAULT NULL::timestamp with time zone, _starts_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin uniquement'; END IF;
  IF _game_slug = 'domino' AND _players_per_match <> 2 THEN _players_per_match := 2; END IF;
  INSERT INTO public.tournaments(name, description, game_slug, format, players_per_match, max_players,
    entry_fee_ar, admin_prize_pool_ar, winners_count, prize_1_pct, prize_2_pct, prize_3_pct,
    pool_size, qualifiers_per_pool, max_concurrent_matches, lobby_minutes,
    registration_closes_at, starts_at, status, created_by)
  VALUES (_name, _description, _game_slug, _format, _players_per_match, _max_players,
    _entry_fee_ar, _admin_prize_pool_ar, _winners_count, _p1, _p2, _p3,
    _pool_size, _qualifiers_per_pool, _max_concurrent, _lobby_minutes,
    _registration_closes_at, _starts_at, 'open', auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_tournament_delete(_tid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin uniquement'; END IF;
  PERFORM public.admin_tournament_cancel(_tid, 'Tournoi supprimé');
  DELETE FROM public.tournaments WHERE id = _tid;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_tournament_force_winner(_match_id uuid, _entrant_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE m public.tournament_matches%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin uniquement'; END IF;
  SELECT * INTO m FROM public.tournament_matches WHERE id = _match_id;
  IF m.game_id IS NOT NULL THEN
    UPDATE public.ludo_games SET status = 'cancelled', finished_at = now() WHERE id = m.game_id AND status <> 'finished';
    UPDATE public.domino_games SET status = 'cancelled', finished_at = now() WHERE id = m.game_id AND status <> 'finished';
  END IF;
  PERFORM public._t_match_finish(_match_id, _entrant_id);
  PERFORM public.tournament_engine(m.tournament_id);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_tournament_next_stage(_tid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_auto boolean;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin uniquement'; END IF;
  SELECT auto_advance INTO v_auto FROM public.tournaments WHERE id = _tid;
  UPDATE public.tournaments SET auto_advance = true WHERE id = _tid;
  PERFORM public.tournament_engine(_tid);
  UPDATE public.tournaments SET auto_advance = v_auto WHERE id = _tid;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_tournament_set_auto(_tid uuid, _auto boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin uniquement'; END IF;
  UPDATE public.tournaments SET auto_advance = _auto WHERE id = _tid;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_tournament_set_status(_tid uuid, _status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin uniquement'; END IF;
  IF _status NOT IN ('open','running','paused') THEN RAISE EXCEPTION 'statut invalide'; END IF;
  UPDATE public.tournaments SET status = _status WHERE id = _tid;
  IF _status = 'running' THEN PERFORM public.tournament_engine(_tid); END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_tournament_simulate(_tid uuid, _max_steps integer DEFAULT 200)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE t public.tournaments%ROWTYPE; i int := 0; v_done int;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin uniquement'; END IF;
  SELECT * INTO t FROM public.tournaments WHERE id = _tid;
  IF t.id IS NULL THEN RAISE EXCEPTION 'Tournoi introuvable'; END IF;
  IF NOT t.is_simulation THEN RAISE EXCEPTION 'Ce tournoi n''est pas en mode simulation'; END IF;

  WHILE i < _max_steps LOOP
    i := i + 1;
    PERFORM public.tournament_engine(_tid);
    v_done := public._t_sim_resolve(_tid);
    SELECT status INTO t.status FROM public.tournaments WHERE id = _tid;
    EXIT WHEN t.status <> 'running';
    EXIT WHEN v_done = 0 AND NOT EXISTS (
      SELECT 1 FROM public.tournament_matches
       WHERE tournament_id = _tid AND status IN ('scheduled','running'));
  END LOOP;
  PERFORM public.tournament_engine(_tid);

  RETURN public.tournament_sim_report(_tid) || jsonb_build_object('steps', i);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_tournament_simulate_new(_game_slug text DEFAULT 'domino'::text, _format text DEFAULT 'pools'::text, _players integer DEFAULT 16, _players_per_match integer DEFAULT 2, _pool_size integer DEFAULT 4, _qualifiers_per_pool integer DEFAULT 2)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_id uuid; i int;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin uniquement'; END IF;
  IF _players < 2 OR _players > 128 THEN RAISE EXCEPTION 'Nombre de joueurs invalide'; END IF;

  INSERT INTO public.tournaments(
      name, description, game_slug, format, players_per_match, pool_size, qualifiers_per_pool,
      max_players, entry_fee_ar, prize_pool_ar, winners_count, prize_1_pct, prize_2_pct, prize_3_pct,
      lobby_minutes, auto_advance, status, stage, is_simulation, created_by)
  VALUES (
      '🧪 Simulation ' || upper(_game_slug) || ' ' || to_char(now(), 'DD/MM HH24:MI'),
      'Tournoi de test automatique (résultats aléatoires, aucun gain réel)',
      _game_slug, _format, _players_per_match, _pool_size, _qualifiers_per_pool,
      GREATEST(_players, 2), 0, 0, 3, 50, 30, 20,
      1, true, 'open', 'registration', true, auth.uid())
  RETURNING id INTO v_id;

  FOR i IN 1.._players LOOP
    INSERT INTO public.tournament_entrants(tournament_id, display_name, is_bot)
      VALUES (v_id, 'Bot ' || lpad(i::text, 2, '0'), true);
  END LOOP;

  PERFORM public.admin_tournament_start(v_id);
  RETURN public.admin_tournament_simulate(v_id);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_tournament_start(_tid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE t public.tournaments%ROWTYPE; ids uuid[];
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin uniquement'; END IF;
  SELECT * INTO t FROM public.tournaments WHERE id = _tid FOR UPDATE;
  IF t.status <> 'open' THEN RAISE EXCEPTION 'Tournoi déjà lancé'; END IF;
  IF (SELECT count(*) FROM public.tournament_entrants WHERE tournament_id = _tid) < 2 THEN
    RAISE EXCEPTION 'Pas assez de joueurs';
  END IF;
  UPDATE public.tournaments SET status = 'running', started_at = now() WHERE id = _tid;
  IF t.format = 'pools' THEN
    PERFORM public._t_draw_pools(_tid);
  ELSE
    SELECT array_agg(id ORDER BY random()) INTO ids FROM public.tournament_entrants
     WHERE tournament_id = _tid AND status = 'active';
    PERFORM public._t_build_round(_tid, 1, ids);
  END IF;
  PERFORM public.tournament_engine(_tid);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_update_bug_report(_id uuid, _status text, _admin_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  UPDATE public.bug_reports SET
    status     = _status,
    admin_note = COALESCE(_admin_note, admin_note),
    resolved_at = CASE WHEN _status IN ('resolved','closed') THEN now() ELSE resolved_at END
  WHERE id = _id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_update_cms_content(_key text, _content jsonb)
 RETURNS cms_content
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  row public.cms_content;
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.cms_content (key, content, updated_at, updated_by)
  VALUES (_key, _content, now(), auth.uid())
  ON CONFLICT (key) DO UPDATE
    SET content = EXCLUDED.content,
        updated_at = now(),
        updated_by = auth.uid()
  RETURNING * INTO row;
  RETURN row;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_update_community(_room_id uuid, _name text, _image_url text, _enabled boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  UPDATE public.chat_rooms SET name=COALESCE(_name,name), image_url=COALESCE(_image_url,image_url), enabled=COALESCE(_enabled,enabled) WHERE id=_room_id AND type='global';
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_update_referral_settings(_enabled boolean DEFAULT NULL::boolean, _stake_commission_pct numeric DEFAULT NULL::numeric, _stake_commission_max_matches integer DEFAULT NULL::integer, _require_phone boolean DEFAULT NULL::boolean, _max_daily integer DEFAULT NULL::integer, _auto_flag_velocity integer DEFAULT NULL::integer, _campaign_label text DEFAULT NULL::text, _campaign_expires timestamp with time zone DEFAULT NULL::timestamp with time zone, _campaign_bonus_pct numeric DEFAULT NULL::numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Accès refusé'; END IF;
  IF _stake_commission_pct IS NOT NULL
     AND (_stake_commission_pct < 0 OR _stake_commission_pct > 100) THEN
    RAISE EXCEPTION 'Commission invalide (0-100)';
  END IF;
  IF _stake_commission_max_matches IS NOT NULL
     AND _stake_commission_max_matches < 0 THEN
    RAISE EXCEPTION 'Nombre de parties invalide';
  END IF;
  UPDATE public.referral_settings SET
    enabled                      = COALESCE(_enabled, enabled),
    stake_commission_pct         = COALESCE(_stake_commission_pct, stake_commission_pct),
    stake_commission_max_matches = COALESCE(_stake_commission_max_matches, stake_commission_max_matches),
    require_phone_verification   = COALESCE(_require_phone, require_phone_verification),
    max_daily_new_referrals      = COALESCE(_max_daily, max_daily_new_referrals),
    auto_flag_velocity           = COALESCE(_auto_flag_velocity, auto_flag_velocity),
    campaign_label               = COALESCE(_campaign_label, campaign_label),
    campaign_expires_at          = COALESCE(_campaign_expires, campaign_expires_at),
    campaign_bonus_pct           = COALESCE(_campaign_bonus_pct, campaign_bonus_pct),
    updated_at                   = now()
  WHERE id = 1;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_update_settings(_admin_phone text, _admin_label text, _signup_bonus numeric, _referral_pct numeric, _game_commission_pct numeric, _min_deposit numeric, _min_withdraw numeric, _mvola_phone text DEFAULT NULL::text, _mvola_name text DEFAULT NULL::text, _orange_phone text DEFAULT NULL::text, _orange_name text DEFAULT NULL::text, _airtel_phone text DEFAULT NULL::text, _airtel_name text DEFAULT NULL::text, _withdrawal_fee_pct numeric DEFAULT NULL::numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE msg text; nxt public.app_settings%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;

  SELECT * INTO nxt FROM public.app_settings WHERE id = 1;
  nxt.admin_phone := _admin_phone;
  nxt.admin_label := _admin_label;
  nxt.signup_bonus := _signup_bonus;
  nxt.referral_pct := _referral_pct;
  nxt.game_commission_pct := _game_commission_pct;
  nxt.min_deposit := _min_deposit;
  nxt.min_withdraw := _min_withdraw;
  nxt.mvola_phone := _mvola_phone;
  nxt.mvola_name := _mvola_name;
  nxt.orange_phone := _orange_phone;
  nxt.orange_name := _orange_name;
  nxt.airtel_phone := _airtel_phone;
  nxt.airtel_name := _airtel_name;
  nxt.withdrawal_fee_pct := COALESCE(_withdrawal_fee_pct, nxt.withdrawal_fee_pct);

  msg := public._validate_app_settings(nxt);
  IF msg IS NOT NULL THEN RAISE EXCEPTION '%', msg USING ERRCODE = '22023'; END IF;

  UPDATE public.app_settings SET
    admin_phone = nxt.admin_phone, admin_label = nxt.admin_label,
    signup_bonus = nxt.signup_bonus, referral_pct = nxt.referral_pct,
    game_commission_pct = nxt.game_commission_pct,
    min_deposit = nxt.min_deposit, min_withdraw = nxt.min_withdraw,
    mvola_phone = nxt.mvola_phone, mvola_name = nxt.mvola_name,
    orange_phone = nxt.orange_phone, orange_name = nxt.orange_name,
    airtel_phone = nxt.airtel_phone, airtel_name = nxt.airtel_name,
    withdrawal_fee_pct = nxt.withdrawal_fee_pct
  WHERE id = 1;
END;$function$
;

CREATE OR REPLACE FUNCTION public.admin_user_history(_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_result jsonb;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  SELECT jsonb_build_object(
    'profile', (SELECT to_jsonb(p) FROM public.profiles p WHERE p.id=_user_id),
    'transactions', COALESCE((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC) FROM public.transactions t WHERE t.user_id=_user_id),'[]'::jsonb),
    'deposits', COALESCE((SELECT jsonb_agg(to_jsonb(d) ORDER BY d.created_at DESC) FROM public.deposits d WHERE d.user_id=_user_id),'[]'::jsonb),
    'withdrawals', COALESCE((SELECT jsonb_agg(to_jsonb(w) ORDER BY w.created_at DESC) FROM public.withdrawals w WHERE w.user_id=_user_id),'[]'::jsonb),
    'games', COALESCE((SELECT jsonb_agg(jsonb_build_object('game_id',g.id,'status',g.status,'stake',g.stake,'won', g.winner_id=_user_id,'finished_at',g.finished_at) ORDER BY g.created_at DESC)
       FROM public.ludo_games g JOIN public.ludo_participants pp ON pp.game_id=g.id WHERE pp.user_id=_user_id),'[]'::jsonb)
  ) INTO v_result;
  RETURN v_result;
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_validate_round(_tid uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_t public.tournaments%ROWTYPE;
  v_pending int;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;

  SELECT * INTO v_t FROM public.tournaments WHERE id = _tid FOR UPDATE;
  IF v_t.id IS NULL THEN RAISE EXCEPTION 'Tournoi introuvable'; END IF;
  IF v_t.status <> 'running' THEN RAISE EXCEPTION 'Tournoi non en cours'; END IF;
  IF NOT v_t.pending_shuffle THEN RAISE EXCEPTION 'Aucun round en attente de validation'; END IF;

  SELECT count(*) INTO v_pending
    FROM public.tournament_matches
   WHERE tournament_id = _tid AND round = v_t.current_round
     AND status NOT IN ('finished','bye','forfeit');

  IF v_pending > 0 THEN
    RAISE EXCEPTION 'Il reste % match(s) non terminé(s) sur ce round', v_pending;
  END IF;

  UPDATE public.tournaments SET round_validated = true WHERE id = _tid;

  BEGIN
    INSERT INTO public.admin_logs(admin_id, action, target_id, new_value)
      VALUES (auth.uid(), 'tournament_validate_round', _tid,
              jsonb_build_object('round', v_t.current_round));
  EXCEPTION WHEN OTHERS THEN NULL; END;

  RETURN jsonb_build_object('ok', true, 'round', v_t.current_round);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_validate_session(_fingerprint text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _me uuid := auth.uid();
  _rec public.admin_sessions;
BEGIN
  IF _me IS NULL THEN RETURN jsonb_build_object('valid', false, 'reason', 'no_auth'); END IF;

  SELECT * INTO _rec FROM public.admin_sessions
   WHERE user_id = _me AND session_fingerprint = _fingerprint;

  IF NOT FOUND THEN RETURN jsonb_build_object('valid', false, 'reason', 'not_found'); END IF;
  IF _rec.revoked_at IS NOT NULL THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'revoked', 'revoke_reason', _rec.revoke_reason);
  END IF;
  IF _rec.expires_at <= now() THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'expired');
  END IF;

  UPDATE public.admin_sessions SET last_seen_at = now() WHERE id = _rec.id;
  RETURN jsonb_build_object('valid', true, 'expires_at', _rec.expires_at, 'session_id', _rec.id);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_verify_email_otp(_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _me uuid := auth.uid();
  _rec public.admin_email_otps;
  _hash text;
BEGIN
  IF _me IS NULL OR NOT public.has_role(_me, 'admin') THEN
    RAISE EXCEPTION 'Not admin';
  END IF;
  IF _code IS NULL OR length(_code) <> 6 THEN
    RAISE EXCEPTION 'Code invalide';
  END IF;

  _hash := encode(extensions.digest(_code, 'sha256'), 'hex');

  SELECT * INTO _rec FROM public.admin_email_otps
   WHERE user_id = _me AND consumed_at IS NULL AND expires_at > now()
   ORDER BY created_at DESC LIMIT 1 FOR UPDATE;

  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'reason', 'no_active_code'); END IF;

  IF _rec.attempts >= 5 THEN
    UPDATE public.admin_email_otps SET consumed_at = now() WHERE id = _rec.id;
    RETURN jsonb_build_object('ok', false, 'reason', 'too_many_attempts');
  END IF;

  IF _rec.code_hash <> _hash THEN
    UPDATE public.admin_email_otps SET attempts = attempts + 1 WHERE id = _rec.id;
    RETURN jsonb_build_object('ok', false, 'reason', 'bad_code');
  END IF;

  UPDATE public.admin_email_otps SET consumed_at = now() WHERE id = _rec.id;
  RETURN jsonb_build_object('ok', true);
END $function$
;

CREATE OR REPLACE FUNCTION public.admin_verify_phone(_user_id uuid, _approve boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  IF _approve THEN
    UPDATE public.profiles SET phone_verified = true, phone_verification_code = NULL WHERE id = _user_id;
  ELSE
    UPDATE public.profiles SET phone_verified = false, phone_verification_code = NULL, phone_verification_requested_at = NULL WHERE id = _user_id;
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.can_access_realtime_topic(_topic text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _uid uuid := auth.uid();
  _uuid uuid;
BEGIN
  IF _uid IS NULL OR _topic IS NULL OR length(_topic) = 0 THEN
    RETURN false;
  END IF;

  -- Admins can access everything
  IF public.has_role(_uid, 'admin') THEN
    RETURN true;
  END IF;

  -- Personal channel: user:<uid> or presence:<uid>
  IF _topic = 'user:' || _uid::text OR _topic = 'presence:' || _uid::text THEN
    RETURN true;
  END IF;

  -- Extract a uuid from the topic (last colon segment or whole topic)
  BEGIN
    _uuid := split_part(_topic, ':', array_length(string_to_array(_topic, ':'), 1))::uuid;
  EXCEPTION WHEN others THEN
    BEGIN
      _uuid := _topic::uuid;
    EXCEPTION WHEN others THEN
      RETURN false;
    END;
  END;

  IF _uuid IS NULL THEN
    RETURN false;
  END IF;

  -- Chat room membership
  IF EXISTS (SELECT 1 FROM public.chat_members WHERE room_id = _uuid AND user_id = _uid) THEN
    RETURN true;
  END IF;

  -- Game participation (generic helper)
  IF public._is_game_participant(_uuid, _uid) THEN
    RETURN true;
  END IF;

  -- Tournament registration
  IF EXISTS (SELECT 1 FROM public.tournament_registrations WHERE tournament_id = _uuid AND user_id = _uid) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.chat_get_or_create_dm(_other uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_me uuid:=auth.uid(); v_id uuid; v_a uuid; v_b uuid;
BEGIN
  IF v_me IS NULL OR _other IS NULL OR _other=v_me THEN RAISE EXCEPTION 'invalid'; END IF;
  v_a := LEAST(v_me,_other); v_b := GREATEST(v_me,_other);
  SELECT id INTO v_id FROM public.chat_rooms WHERE type='dm' AND dm_user_a=v_a AND dm_user_b=v_b;
  IF v_id IS NOT NULL THEN RETURN v_id; END IF;
  INSERT INTO public.chat_rooms(type,dm_user_a,dm_user_b,created_by) VALUES('dm',v_a,v_b,v_me) RETURNING id INTO v_id;
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.chat_get_or_create_game_room(_game_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_id uuid;
BEGIN
  SELECT id INTO v_id FROM public.chat_rooms WHERE type='game' AND game_id=_game_id;
  IF v_id IS NOT NULL THEN RETURN v_id; END IF;
  INSERT INTO public.chat_rooms(type,game_id,name) VALUES('game',_game_id,'Partie') RETURNING id INTO v_id;
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.chat_join_room(_room_id uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  INSERT INTO public.chat_members(room_id,user_id) VALUES (_room_id, auth.uid()) ON CONFLICT DO NOTHING;
$function$
;

CREATE OR REPLACE FUNCTION public.chat_leave_room(_room_id uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  DELETE FROM public.chat_members WHERE room_id=_room_id AND user_id=auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.chat_pin(_message_id uuid, _pin boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  UPDATE public.chat_messages SET pinned=_pin WHERE id=_message_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.chat_presence_ping(_game uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  INSERT INTO public.chat_presence(user_id,last_seen,current_game) VALUES (auth.uid(), now(), _game)
    ON CONFLICT (user_id) DO UPDATE SET last_seen=now(), current_game=_game;
END $function$
;

CREATE OR REPLACE FUNCTION public.chat_send(_room_id uuid, _body text, _reply_to uuid DEFAULT NULL::uuid, _attachment_url text DEFAULT NULL::text, _attachment_type text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_me uuid:=auth.uid(); v_id uuid; v_count int; v_mute public.chat_mutes%ROWTYPE;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'auth'; END IF;

  -- ROOM ACCESS GUARD
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_rooms r WHERE r.id = _room_id AND r.enabled = true AND (
      r.type = 'global'
      OR (r.type = 'dm' AND (r.dm_user_a = v_me OR r.dm_user_b = v_me))
      OR (r.type = 'game' AND (
            public._is_game_participant(r.game_id, v_me)
            OR EXISTS (SELECT 1 FROM public.game_spectators s WHERE s.game_id=r.game_id AND s.user_id=v_me)
         ))
      OR public.is_admin()
    )
  ) THEN
    RAISE EXCEPTION 'Accès refusé à ce salon';
  END IF;

  SELECT * INTO v_mute FROM public.chat_mutes WHERE user_id=v_me;
  IF v_mute.user_id IS NOT NULL AND (v_mute.banned OR (v_mute.until IS NOT NULL AND v_mute.until>now())) THEN
    RAISE EXCEPTION 'Vous êtes muté';
  END IF;
  SELECT count(*) INTO v_count FROM public.chat_messages WHERE user_id=v_me AND created_at>now()-interval '5 seconds';
  IF v_count >= 5 THEN RAISE EXCEPTION 'Trop de messages, ralentissez'; END IF;
  INSERT INTO public.chat_messages(room_id,user_id,body,reply_to,attachment_url,attachment_type)
    VALUES (_room_id, v_me, NULLIF(_body,''), _reply_to, _attachment_url, _attachment_type) RETURNING id INTO v_id;
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.chat_typing(_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  INSERT INTO public.chat_presence(user_id,last_seen,typing_room,typing_until) VALUES (auth.uid(), now(), _room_id, now()+interval '4 seconds')
    ON CONFLICT (user_id) DO UPDATE SET last_seen=now(), typing_room=_room_id, typing_until=now()+interval '4 seconds';
END $function$
;

CREATE OR REPLACE FUNCTION public.check_and_award_achievements(_uid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_wins int; v_games int; v_streak int;
  v_ludo_wins int:=0; v_chess_wins int:=0; v_domino_wins int:=0; v_fanorona_wins int:=0; v_rami_wins int:=0;
  v_has_deposit boolean := false;
BEGIN
  SELECT COALESCE(total_wins,0), COALESCE(total_games,0), COALESCE(daily_streak,0)
  INTO v_wins, v_games, v_streak FROM public.profiles WHERE id = _uid;
  BEGIN SELECT COUNT(*) INTO v_ludo_wins     FROM public.ludo_games     WHERE winner_id = _uid; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN SELECT COUNT(*) INTO v_chess_wins    FROM public.chess_games    WHERE winner_id = _uid; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN SELECT COUNT(*) INTO v_domino_wins   FROM public.domino_games   WHERE winner_id = _uid; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN SELECT COUNT(*) INTO v_fanorona_wins FROM public.fanorona_games WHERE winner_id = _uid; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN SELECT COUNT(*) INTO v_rami_wins     FROM public.rami_games     WHERE winner_id = _uid; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN SELECT EXISTS(SELECT 1 FROM public.deposits WHERE user_id = _uid AND status = 'approved') INTO v_has_deposit; EXCEPTION WHEN OTHERS THEN NULL; END;
  IF v_wins   >= 1   THEN INSERT INTO public.player_achievements(user_id, achievement_key) VALUES(_uid,'first_win')   ON CONFLICT DO NOTHING; END IF;
  IF v_wins   >= 10  THEN INSERT INTO public.player_achievements(user_id, achievement_key) VALUES(_uid,'wins_10')     ON CONFLICT DO NOTHING; END IF;
  IF v_wins   >= 50  THEN INSERT INTO public.player_achievements(user_id, achievement_key) VALUES(_uid,'wins_50')     ON CONFLICT DO NOTHING; END IF;
  IF v_wins   >= 100 THEN INSERT INTO public.player_achievements(user_id, achievement_key) VALUES(_uid,'wins_100')    ON CONFLICT DO NOTHING; END IF;
  IF v_wins   >= 200 THEN INSERT INTO public.player_achievements(user_id, achievement_key) VALUES(_uid,'wins_200')    ON CONFLICT DO NOTHING; END IF;
  IF v_games  >= 50  THEN INSERT INTO public.player_achievements(user_id, achievement_key) VALUES(_uid,'games_50')    ON CONFLICT DO NOTHING; END IF;
  IF v_games  >= 100 THEN INSERT INTO public.player_achievements(user_id, achievement_key) VALUES(_uid,'games_100')   ON CONFLICT DO NOTHING; END IF;
  IF v_streak >= 7   THEN INSERT INTO public.player_achievements(user_id, achievement_key) VALUES(_uid,'streak_7')    ON CONFLICT DO NOTHING; END IF;
  IF v_streak >= 30  THEN INSERT INTO public.player_achievements(user_id, achievement_key) VALUES(_uid,'streak_30')   ON CONFLICT DO NOTHING; END IF;
  IF v_ludo_wins    >= 10 THEN INSERT INTO public.player_achievements(user_id, achievement_key) VALUES(_uid,'ludo_10')     ON CONFLICT DO NOTHING; END IF;
  IF v_chess_wins   >= 10 THEN INSERT INTO public.player_achievements(user_id, achievement_key) VALUES(_uid,'chess_10')    ON CONFLICT DO NOTHING; END IF;
  IF v_domino_wins  >= 10 THEN INSERT INTO public.player_achievements(user_id, achievement_key) VALUES(_uid,'domino_10')   ON CONFLICT DO NOTHING; END IF;
  IF v_fanorona_wins>= 10 THEN INSERT INTO public.player_achievements(user_id, achievement_key) VALUES(_uid,'fanorona_10') ON CONFLICT DO NOTHING; END IF;
  IF v_rami_wins    >= 10 THEN INSERT INTO public.player_achievements(user_id, achievement_key) VALUES(_uid,'rami_10')     ON CONFLICT DO NOTHING; END IF;
  IF v_has_deposit  THEN INSERT INTO public.player_achievements(user_id, achievement_key) VALUES(_uid,'first_deposit') ON CONFLICT DO NOTHING; END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.check_pseudo_availability(_pseudo text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT NOT EXISTS(SELECT 1 FROM public.profiles WHERE lower(pseudo) = lower(trim(_pseudo)))
$function$
;

CREATE OR REPLACE FUNCTION public.check_pseudo_available(p_pseudo text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ SELECT NOT EXISTS (SELECT 1 FROM public.profiles WHERE lower(pseudo) = lower(trim(p_pseudo))); $function$
;

CREATE OR REPLACE FUNCTION public.chess_accept_draw(_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_g chess_games%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO v_g FROM chess_games WHERE id=_id FOR UPDATE;
  IF v_g.draw_offered_by IS NULL OR v_g.draw_offered_by = v_uid THEN RAISE EXCEPTION 'no draw offer'; END IF;
  IF v_g.white_id <> v_uid AND v_g.black_id <> v_uid THEN RAISE EXCEPTION 'not a participant'; END IF;
  PERFORM public._chess_settle(_id, NULL, true, 'draw_agreed');
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_add_bot(_game_id uuid, _difficulty text DEFAULT 'medium'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_is_admin boolean := public.is_admin();
  g public.chess_games%ROWTYPE;
  v_bot_id uuid := gen_random_uuid();
  v_bot_mail text;
  v_intel int;
  v_bot_name text;
  v_is_stake boolean;
  v_add_pot numeric;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Connexion requise'; END IF;
  SELECT * INTO g FROM public.chess_games WHERE id = _game_id FOR UPDATE;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  IF g.status <> 'open' THEN RAISE EXCEPTION 'La partie a déjà commencé'; END IF;
  IF g.white_id IS NOT NULL AND g.black_id IS NOT NULL THEN RAISE EXCEPTION 'Partie pleine'; END IF;

  v_is_stake := COALESCE(g.stake,0) > 0;

  IF v_is_stake AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Bots avec mise réservés à l''administrateur';
  END IF;
  IF NOT v_is_admin AND g.host_id <> v_uid AND g.white_id <> v_uid AND g.black_id <> v_uid THEN
    RAISE EXCEPTION 'Rejoignez la partie pour ajouter un bot';
  END IF;

  v_intel := CASE lower(COALESCE(_difficulty,'medium'))
    WHEN 'easy' THEN 30 WHEN 'hard' THEN 95 WHEN 'expert' THEN 100 ELSE 70 END;
  v_bot_name := CASE v_intel WHEN 30 THEN 'Bot Facile'
                             WHEN 95 THEN 'Bot Fort'
                             WHEN 100 THEN 'Bot Expert'
                             ELSE 'Bot Moyen' END;

  v_bot_mail := 'chessbot_' || v_bot_id::text || '@bot.lalaomada.internal';
  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change, email_change_token_new
  ) VALUES (
    v_bot_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    v_bot_mail, crypt(gen_random_uuid()::text, gen_salt('bf')), now(),
    jsonb_build_object('pseudo', v_bot_name, 'is_bot', true),
    now(), now(), '', '', '', ''
  );
  UPDATE public.profiles SET balance_ar=0, pseudo=v_bot_name, avatar_url=NULL, is_bot=true WHERE id = v_bot_id;
  DELETE FROM public.transactions WHERE user_id = v_bot_id;

  v_add_pot := CASE WHEN v_is_stake THEN g.stake ELSE 0 END;

  IF g.white_id IS NULL THEN
    UPDATE public.chess_games
       SET white_id=v_bot_id, white_is_bot=true, bot_intelligence=v_intel, bot_name=v_bot_name,
           pot = pot + v_add_pot,
           status='playing', started_at=now(), last_move_at=now()
     WHERE id = _game_id;
  ELSE
    UPDATE public.chess_games
       SET black_id=v_bot_id, black_is_bot=true, bot_intelligence=v_intel, bot_name=v_bot_name,
           pot = pot + v_add_pot,
           status='playing', started_at=now(), last_move_at=now()
     WHERE id = _game_id;
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_auto_end(_game_id uuid, _winner uuid, _draw boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_g chess_games%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO v_g FROM chess_games WHERE id = _game_id FOR UPDATE;
  IF v_g.status <> 'playing' THEN RETURN; END IF;
  IF v_uid <> v_g.white_id AND v_uid <> v_g.black_id THEN RAISE EXCEPTION 'not a player'; END IF;
  IF NOT _draw AND _winner IS NOT NULL
     AND _winner <> v_g.white_id AND _winner <> v_g.black_id THEN
    RAISE EXCEPTION 'invalid winner';
  END IF;
  PERFORM public._chess_settle(_game_id, _winner, coalesce(_draw,false),
                               CASE WHEN _draw THEN 'draw' ELSE 'auto' END);
END $function$
;

-- ═══════════ 0007_functions_08.sql ═══════════
-- 0007_functions_08.sql
-- Fonctions et procédures (8/12)

CREATE OR REPLACE FUNCTION public.chess_bot_play(_id uuid, _uci text, _san text, _fen_after text, _elapsed_ms integer DEFAULT 0)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_g chess_games%ROWTYPE;
  v_bot uuid;
  v_bot_color text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO v_g FROM chess_games WHERE id=_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'game not found'; END IF;
  IF v_g.mode <> 'solo' THEN RAISE EXCEPTION 'not a solo game'; END IF;
  IF v_g.status <> 'playing' THEN RAISE EXCEPTION 'game not active'; END IF;

  IF v_g.white_id = v_uid AND v_g.black_is_bot THEN v_bot := v_g.black_id; v_bot_color := 'b';
  ELSIF v_g.black_id = v_uid AND v_g.white_is_bot THEN v_bot := v_g.white_id; v_bot_color := 'w';
  ELSE RAISE EXCEPTION 'not a solo-bot game'; END IF;

  IF v_g.turn <> v_bot_color THEN RAISE EXCEPTION 'not bot turn'; END IF;

  INSERT INTO chess_moves(game_id, ply, san, uci, fen_after, by_user)
    VALUES (_id, v_g.ply+1, _san, _uci, _fen_after, v_bot);

  UPDATE chess_games SET
    fen = _fen_after,
    turn = CASE WHEN v_g.turn='w' THEN 'b' ELSE 'w' END,
    ply = v_g.ply + 1,
    last_move_at = now(),
    white_time_ms = CASE WHEN v_bot_color='w' THEN greatest(0, white_time_ms - coalesce(_elapsed_ms,0)) ELSE white_time_ms END,
    black_time_ms = CASE WHEN v_bot_color='b' THEN greatest(0, black_time_ms - coalesce(_elapsed_ms,0)) ELSE black_time_ms END
  WHERE id=_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_check_global_timeout(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g public.chess_games%ROWTYPE;
  loser uuid;
  winner uuid;
BEGIN
  SELECT * INTO g FROM public.chess_games WHERE id = _game_id FOR UPDATE;
  IF NOT FOUND OR g.status <> 'playing' OR g.game_deadline IS NULL THEN RETURN; END IF;
  IF now() < g.game_deadline THEN RETURN; END IF;

  IF g.turn = 'w' THEN
    loser := g.white_id; winner := g.black_id;
  ELSE
    loser := g.black_id; winner := g.white_id;
  END IF;

  UPDATE public.chess_games
     SET status = 'finished', winner_id = winner, finished_at = now()
   WHERE id = _game_id;

  IF winner IS NOT NULL AND g.pot > 0 THEN
    UPDATE public.profiles SET balance = COALESCE(balance,0) + g.pot WHERE user_id = winner;
    INSERT INTO public.transactions(user_id, kind, amount, meta)
      VALUES (winner, 'game_win', g.pot, jsonb_build_object('game','chess','game_id',_game_id,'reason','global_timeout'));
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.chess_claim_win(_game_id uuid, _winner uuid, _draw boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_g chess_games%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO v_g FROM chess_games WHERE id = _game_id FOR UPDATE;
  IF v_g.status <> 'playing' THEN RAISE EXCEPTION 'not active'; END IF;
  IF v_uid <> v_g.white_id AND v_uid <> v_g.black_id THEN RAISE EXCEPTION 'not a player'; END IF;
  IF NOT _draw AND _winner <> v_g.white_id AND _winner <> v_g.black_id THEN RAISE EXCEPTION 'invalid winner'; END IF;
  PERFORM public._chess_payout(_game_id, _winner, _draw);
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_create(_stake numeric, _private boolean DEFAULT true, _commission numeric DEFAULT 10)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_bal numeric; v_code text; v_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  IF _stake < 0 THEN RAISE EXCEPTION 'invalid stake'; END IF;
  SELECT balance_ar INTO v_bal FROM profiles WHERE id = v_uid;
  IF v_bal < _stake THEN RAISE EXCEPTION 'insufficient balance'; END IF;
  IF _private THEN v_code := upper(substring(md5(random()::text||clock_timestamp()::text) from 1 for 6)); END IF;
  INSERT INTO chess_games(host_id, white_id, stake, pot, commission_pct, is_private, room_code)
  VALUES (v_uid, v_uid, _stake, _stake, _commission, _private, v_code)
  RETURNING id INTO v_id;
  UPDATE profiles SET balance_ar = balance_ar - _stake WHERE id = v_uid;
  INSERT INTO transactions(user_id, type, amount, ref_id, note) VALUES (v_uid, 'chess_stake', -_stake, v_id, 'Create chess');
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_create_friends(_color text DEFAULT 'white'::text, _time_min integer DEFAULT 10)
 RETURNS TABLE(id uuid, code text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_id  uuid;
  v_code text := public._chess_gen_code();
  v_human_w boolean := (lower(coalesce(_color,'white')) <> 'black');
  v_ms int := greatest(60000, coalesce(_time_min,10) * 60000);
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  INSERT INTO public.chess_games(
    host_id, white_id, black_id, status, mode,
    stake, pot, commission_pct, is_private, room_code,
    time_control_min, white_time_ms, black_time_ms,
    fen, turn, ply
  ) VALUES (
    v_uid,
    CASE WHEN v_human_w THEN v_uid ELSE NULL END,
    CASE WHEN v_human_w THEN NULL ELSE v_uid END,
    'open', 'friends',
    0, 0, 0, true, v_code,
    coalesce(_time_min,10), v_ms, v_ms,
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', 'w', 0
  ) RETURNING chess_games.id INTO v_id;
  RETURN QUERY SELECT v_id, v_code;
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_create_solo(_difficulty integer DEFAULT 2, _color text DEFAULT 'white'::text, _time_min integer DEFAULT 10)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_bot uuid;
  v_id  uuid;
  v_human_w boolean := (lower(coalesce(_color,'white')) <> 'black');
  v_ms int := greatest(60000, coalesce(_time_min,10) * 60000);
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  v_bot := public._chess_ephemeral_bot('Joueur');

  INSERT INTO public.chess_games(
    host_id, white_id, black_id, status, mode,
    stake, pot, commission_pct, is_private, room_code,
    white_is_bot, black_is_bot,
    time_control_min, white_time_ms, black_time_ms,
    bot_intelligence, bot_name,
    started_at, last_move_at,
    fen, turn, ply
  ) VALUES (
    v_uid,
    CASE WHEN v_human_w THEN v_uid ELSE v_bot END,
    CASE WHEN v_human_w THEN v_bot ELSE v_uid END,
    'playing', 'solo',
    0, 0, 0, true, public._chess_gen_code(),
    NOT v_human_w, v_human_w,
    coalesce(_time_min,10), v_ms, v_ms,
    coalesce(_difficulty,2), 'Joueur',
    now(), now(),
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', 'w', 0
  ) RETURNING id INTO v_id;
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_create_stake(_stake numeric, _color text DEFAULT 'white'::text, _time_min integer DEFAULT 10)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_id  uuid;
  v_human_w boolean := (lower(coalesce(_color,'white')) <> 'black');
  v_ms int := greatest(60000, coalesce(_time_min,10) * 60000);
  v_bal numeric;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  IF _stake <= 0 THEN RAISE EXCEPTION 'stake must be positive'; END IF;
  SELECT balance_ar INTO v_bal FROM profiles WHERE id = v_uid FOR UPDATE;
  IF coalesce(v_bal,0) < _stake THEN RAISE EXCEPTION 'insufficient balance'; END IF;
  UPDATE profiles SET balance_ar = balance_ar - _stake WHERE id = v_uid;
  INSERT INTO transactions(user_id, type, amount, meta) VALUES (v_uid, 'chess_stake', -_stake, jsonb_build_object('kind','hold'));

  INSERT INTO public.chess_games(
    host_id, white_id, black_id, status, mode,
    stake, pot, commission_pct, is_private, room_code,
    time_control_min, white_time_ms, black_time_ms,
    fen, turn, ply
  ) VALUES (
    v_uid,
    CASE WHEN v_human_w THEN v_uid ELSE NULL END,
    CASE WHEN v_human_w THEN NULL ELSE v_uid END,
    'open', 'stake',
    _stake, _stake, 10, false, public._chess_gen_code(),
    coalesce(_time_min,10), v_ms, v_ms,
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', 'w', 0
  ) RETURNING id INTO v_id;
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_decline_draw(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  UPDATE chess_games SET draw_offered_by = NULL
    WHERE id=_game_id AND draw_offered_by IS NOT NULL AND draw_offered_by <> v_uid
      AND (white_id = v_uid OR black_id = v_uid);
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_draw_finalize(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_g public.chess_games%ROWTYPE; v_starter uuid; v_other uuid; _cfg record;
BEGIN
  SELECT * INTO v_g FROM public.chess_games WHERE id=_game_id FOR UPDATE;
  IF v_g.id IS NULL OR v_g.status <> 'drawing' OR v_g.draw_result_color IS NULL THEN RETURN; END IF;
  -- NO time guard: client controls the visual delay; server fires immediately.

  v_starter := CASE WHEN v_g.draw_result_color = 'w' THEN v_g.draw_white_by ELSE v_g.draw_black_by END;
  v_other   := CASE WHEN v_starter = v_g.white_id THEN v_g.black_id ELSE v_g.white_id END;

  SELECT * INTO _cfg FROM public._game_cfg('chess');
  UPDATE public.chess_games
     SET status='playing',
         white_id = v_starter,
         black_id = v_other,
         started_at = now(),
         turn_deadline = now() + (COALESCE(_cfg.turn_timer_seconds,60) || ' seconds')::interval
   WHERE id=_game_id AND status='drawing';
END; $function$
;

CREATE OR REPLACE FUNCTION public.chess_draw_pick_color(_game_id uuid, _color text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_g public.chess_games%ROWTYPE; v_other uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  IF _color NOT IN ('w','b') THEN RAISE EXCEPTION 'invalid color'; END IF;
  SELECT * INTO v_g FROM public.chess_games WHERE id=_game_id FOR UPDATE;
  IF v_g.id IS NULL OR v_g.status <> 'drawing' THEN RAISE EXCEPTION 'not drawing'; END IF;
  IF v_uid <> v_g.white_id AND v_uid <> v_g.black_id THEN RAISE EXCEPTION 'not a player'; END IF;
  IF v_g.draw_result_color IS NOT NULL THEN RETURN; END IF;
  -- already picked
  IF v_g.draw_white_by = v_uid OR v_g.draw_black_by = v_uid THEN RETURN; END IF;

  v_other := CASE WHEN v_uid = v_g.white_id THEN v_g.black_id ELSE v_g.white_id END;

  IF _color = 'w' THEN
    IF v_g.draw_white_by IS NOT NULL THEN RAISE EXCEPTION 'color taken'; END IF;
    UPDATE public.chess_games
       SET draw_white_by = v_uid,
           draw_black_by = COALESCE(draw_black_by, v_other)
     WHERE id=_game_id;
  ELSE
    IF v_g.draw_black_by IS NOT NULL THEN RAISE EXCEPTION 'color taken'; END IF;
    UPDATE public.chess_games
       SET draw_black_by = v_uid,
           draw_white_by = COALESCE(draw_white_by, v_other)
     WHERE id=_game_id;
  END IF;
END; $function$
;

CREATE OR REPLACE FUNCTION public.chess_finish(_id uuid, _winner uuid, _draw boolean, _reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_g chess_games%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO v_g FROM chess_games WHERE id=_id;
  IF v_uid NOT IN (coalesce(v_g.white_id, v_uid), coalesce(v_g.black_id, v_uid)) THEN
    -- ensure at least one side matches
    IF v_g.white_id <> v_uid AND v_g.black_id <> v_uid THEN
      RAISE EXCEPTION 'not a participant';
    END IF;
  END IF;
  PERFORM public._chess_settle(_id, _winner, coalesce(_draw,false), _reason);
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_join(_game_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_g chess_games%ROWTYPE;
  v_bal numeric;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO v_g FROM chess_games WHERE id = _game_id AND status = 'open' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'game not joinable'; END IF;
  IF v_g.white_id = v_uid OR v_g.black_id = v_uid THEN RETURN _game_id; END IF;
  IF v_g.white_id IS NOT NULL AND v_g.black_id IS NOT NULL THEN RAISE EXCEPTION 'full'; END IF;

  IF coalesce(v_g.stake,0) > 0 THEN
    SELECT balance_ar INTO v_bal FROM profiles WHERE id = v_uid FOR UPDATE;
    IF coalesce(v_bal,0) < v_g.stake THEN RAISE EXCEPTION 'insufficient balance'; END IF;
    UPDATE profiles SET balance_ar = balance_ar - v_g.stake WHERE id = v_uid;
    INSERT INTO transactions(user_id, type, amount, meta)
      VALUES (v_uid, 'chess_stake', -v_g.stake, jsonb_build_object('kind','hold','game',_game_id));
  END IF;

  IF v_g.white_id IS NULL THEN
    UPDATE chess_games
      SET white_id = v_uid,
          pot = pot + coalesce(v_g.stake,0),
          status = 'playing',
          started_at = now(),
          last_move_at = now()
      WHERE id = _game_id;
  ELSE
    UPDATE chess_games
      SET black_id = v_uid,
          pot = pot + coalesce(v_g.stake,0),
          status = 'playing',
          started_at = now(),
          last_move_at = now()
      WHERE id = _game_id;
  END IF;

  RETURN _game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_join_friends(_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_g   chess_games%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO v_g FROM chess_games
    WHERE upper(room_code) = upper(_code) AND status = 'open'
    ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'game not found'; END IF;
  IF v_g.white_id = v_uid OR v_g.black_id = v_uid THEN RETURN v_g.id; END IF;
  IF v_g.white_id IS NULL THEN
    UPDATE chess_games SET white_id = v_uid, status='playing', started_at=now(), last_move_at=now() WHERE id = v_g.id;
  ELSIF v_g.black_id IS NULL THEN
    UPDATE chess_games SET black_id = v_uid, status='playing', started_at=now(), last_move_at=now() WHERE id = v_g.id;
  ELSE
    RAISE EXCEPTION 'game full';
  END IF;
  RETURN v_g.id;
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_join_stake(_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_g chess_games%ROWTYPE;
  v_bal numeric;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO v_g FROM chess_games WHERE id=_id AND status='open' AND mode='stake' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'game not joinable'; END IF;
  IF v_g.white_id = v_uid OR v_g.black_id = v_uid THEN RETURN _id; END IF;
  IF v_g.stake > 0 THEN
    SELECT balance_ar INTO v_bal FROM profiles WHERE id = v_uid FOR UPDATE;
    IF coalesce(v_bal,0) < v_g.stake THEN RAISE EXCEPTION 'insufficient balance'; END IF;
    UPDATE profiles SET balance_ar = balance_ar - v_g.stake WHERE id = v_uid;
    INSERT INTO transactions(user_id, type, amount, meta) VALUES (v_uid, 'chess_stake', -v_g.stake, jsonb_build_object('kind','hold','game',_id));
  END IF;
  IF v_g.white_id IS NULL THEN
    UPDATE chess_games SET white_id=v_uid, pot=pot+v_g.stake, status='playing', started_at=now(), last_move_at=now() WHERE id=_id;
  ELSE
    UPDATE chess_games SET black_id=v_uid, pot=pot+v_g.stake, status='playing', started_at=now(), last_move_at=now() WHERE id=_id;
  END IF;
  RETURN _id;
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_offer_draw(_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_g chess_games%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO v_g FROM chess_games WHERE id=_id FOR UPDATE;
  IF v_g.white_id <> v_uid AND v_g.black_id <> v_uid THEN RAISE EXCEPTION 'not a participant'; END IF;
  UPDATE chess_games SET draw_offered_by = v_uid WHERE id=_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_play(_id uuid, _uci text, _san text, _fen_after text, _elapsed_ms integer DEFAULT 0)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_g chess_games%ROWTYPE;
  v_new_turn text;
  v_my_color text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO v_g FROM chess_games WHERE id=_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'game not found'; END IF;
  IF v_g.status <> 'playing' THEN RAISE EXCEPTION 'game not active'; END IF;

  IF v_g.white_id = v_uid THEN v_my_color := 'w';
  ELSIF v_g.black_id = v_uid THEN v_my_color := 'b';
  ELSE RAISE EXCEPTION 'not a participant'; END IF;

  IF v_g.turn <> v_my_color THEN RAISE EXCEPTION 'not your turn'; END IF;

  v_new_turn := CASE WHEN v_g.turn='w' THEN 'b' ELSE 'w' END;

  INSERT INTO chess_moves(game_id, ply, san, uci, fen_after, by_user)
    VALUES (_id, v_g.ply+1, _san, _uci, _fen_after, v_uid);

  UPDATE chess_games SET
    fen = _fen_after,
    turn = v_new_turn,
    ply = v_g.ply + 1,
    last_move_at = now(),
    white_time_ms = CASE WHEN v_my_color='w' THEN greatest(0, white_time_ms - coalesce(_elapsed_ms,0)) ELSE white_time_ms END,
    black_time_ms = CASE WHEN v_my_color='b' THEN greatest(0, black_time_ms - coalesce(_elapsed_ms,0)) ELSE black_time_ms END,
    draw_offered_by = CASE WHEN draw_offered_by IS NOT NULL AND draw_offered_by = v_uid THEN NULL ELSE draw_offered_by END
  WHERE id=_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_request_or_accept_draw(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_white uuid; v_black uuid; v_status text; v_offered uuid;
BEGIN
  SELECT white_player_id, black_player_id, status, draw_offered_by
    INTO v_white, v_black, v_status, v_offered
  FROM public.chess_games WHERE id = _game_id FOR UPDATE;
  IF v_status <> 'active' THEN RETURN; END IF;
  IF v_uid <> v_white AND v_uid <> v_black THEN RETURN; END IF;
  IF v_offered IS NULL THEN
    UPDATE public.chess_games SET draw_offered_by = v_uid, updated_at = now() WHERE id = _game_id;
  ELSIF v_offered <> v_uid THEN
    UPDATE public.chess_games SET status='finished', result='draw', draw_offered_by=NULL, finished_at=now(), updated_at=now() WHERE id=_game_id;
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.chess_resign(_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_g chess_games%ROWTYPE;
  v_winner uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO v_g FROM chess_games WHERE id=_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'game not found'; END IF;
  IF v_g.white_id = v_uid THEN v_winner := v_g.black_id;
  ELSIF v_g.black_id = v_uid THEN v_winner := v_g.white_id;
  ELSE RAISE EXCEPTION 'not a participant'; END IF;
  PERFORM public._chess_settle(_id, v_winner, false, 'resign');
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_set_ready(_game_id uuid, _ready boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_g public.chess_games%ROWTYPE; _cfg record;
        v_w uuid; v_b uuid; v_swap boolean;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO v_g FROM public.chess_games WHERE id = _game_id FOR UPDATE;
  IF v_g.id IS NULL THEN RAISE EXCEPTION 'game not found'; END IF;
  IF v_g.status <> 'open' THEN RETURN; END IF;
  IF v_uid = v_g.white_id THEN
    UPDATE public.chess_games SET ready_white = COALESCE(_ready,false) WHERE id=_game_id;
  ELSIF v_uid = v_g.black_id THEN
    UPDATE public.chess_games SET ready_black = COALESCE(_ready,false) WHERE id=_game_id;
  ELSE RAISE EXCEPTION 'not a player'; END IF;

  SELECT * INTO v_g FROM public.chess_games WHERE id=_game_id;
  IF v_g.white_id IS NOT NULL AND v_g.black_id IS NOT NULL AND v_g.ready_white AND v_g.ready_black THEN
    SELECT * INTO _cfg FROM public._game_cfg('chess');
    -- random 50/50 swap
    v_swap := (get_byte(gen_random_bytes(1),0) % 2) = 1;
    IF v_swap THEN
      v_w := v_g.black_id; v_b := v_g.white_id;
    ELSE
      v_w := v_g.white_id; v_b := v_g.black_id;
    END IF;
    UPDATE public.chess_games
       SET status='playing',
           white_id = v_w,
           black_id = v_b,
           started_at = now(),
           turn_deadline = now() + (COALESCE(_cfg.turn_timer_seconds,60) || ' seconds')::interval
     WHERE id=_game_id AND status='open';
  END IF;
END; $function$
;

CREATE OR REPLACE FUNCTION public.chess_start_solo_bot(_difficulty text DEFAULT 'medium'::text, _color text DEFAULT 'white'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid      uuid := auth.uid();
  v_bot_id   uuid := gen_random_uuid();
  v_bot_mail text;
  v_id       uuid;
  v_code     text;
  v_human_w  boolean := (_color IS NULL OR lower(_color) <> 'black');
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;

  v_bot_mail := 'chessbot_' || v_bot_id::text || '@bot.lalaomada.internal';

  INSERT INTO auth.users (
    id, instance_id, aud, role,
    email, encrypted_password, email_confirmed_at,
    raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token, email_change, email_change_token_new
  ) VALUES (
    v_bot_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    v_bot_mail,
    crypt(gen_random_uuid()::text, gen_salt('bf')),
    now(),
    jsonb_build_object('pseudo', 'Bot', 'is_bot', true),
    now(), now(),
    '', '', '', ''
  );

  UPDATE public.profiles
    SET balance_ar = 0, pseudo = 'Bot', avatar_url = NULL, is_bot = true
    WHERE id = v_bot_id;

  DELETE FROM public.transactions WHERE user_id = v_bot_id;

  v_code := upper(substring(md5(random()::text||clock_timestamp()::text) from 1 for 6));

  INSERT INTO public.chess_games(
    host_id, white_id, black_id, status,
    stake, pot, commission_pct, is_private, room_code,
    white_is_bot, black_is_bot, started_at, last_move_at
  ) VALUES (
    v_uid,
    CASE WHEN v_human_w THEN v_uid    ELSE v_bot_id END,
    CASE WHEN v_human_w THEN v_bot_id ELSE v_uid    END,
    'playing',
    0, 0, 0, true, v_code,
    NOT v_human_w, v_human_w,
    now(), now()
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_tick(_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_g chess_games%ROWTYPE;
  v_elapsed_ms int;
  v_remaining int;
  v_winner uuid;
BEGIN
  SELECT * INTO v_g FROM chess_games WHERE id=_id FOR UPDATE;
  IF NOT FOUND OR v_g.status <> 'playing' THEN RETURN; END IF;
  IF coalesce(v_g.paused, false) THEN RETURN; END IF;
  v_elapsed_ms := greatest(0, floor(extract(epoch FROM (now() - coalesce(v_g.last_move_at, v_g.started_at, now())))*1000)::int);
  IF v_g.turn = 'w' THEN
    v_remaining := v_g.white_time_ms - v_elapsed_ms;
    v_winner := v_g.black_id;
  ELSE
    v_remaining := v_g.black_time_ms - v_elapsed_ms;
    v_winner := v_g.white_id;
  END IF;
  IF v_remaining <= 0 THEN
    PERFORM public._chess_settle(_id, v_winner, false, 'timeout');
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.chess_tick_all()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  r record; n int := 0;
BEGIN
  FOR r IN SELECT id FROM chess_games WHERE status = 'playing' AND NOT coalesce(paused,false) LOOP
    PERFORM public.chess_tick(r.id);
    n := n + 1;
  END LOOP;
  RETURN n;
END $function$
;

CREATE OR REPLACE FUNCTION public.claim_daily_bonus()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_last_date date; v_streak int; v_new_streak int; v_bonus numeric;
  v_today date := (now() at time zone 'Indian/Antananarivo')::date;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT last_daily_claim::date, coalesce(daily_streak, 0) INTO v_last_date, v_streak
    FROM public.profiles WHERE id = v_uid FOR UPDATE;
  IF v_last_date = v_today THEN
    RETURN json_build_object('success', false, 'already_claimed', true, 'streak', v_streak);
  END IF;
  IF v_last_date = v_today - 1 THEN v_new_streak := v_streak + 1; ELSE v_new_streak := 1; END IF;
  IF v_new_streak > 7 THEN v_new_streak := 1; END IF;
  v_bonus := 300 + (v_new_streak * 200);
  IF v_new_streak = 7 THEN v_bonus := v_bonus + 2000; END IF;
  UPDATE public.profiles SET balance_ar = balance_ar + v_bonus, daily_streak = v_new_streak, last_daily_claim = now() WHERE id = v_uid;
  RETURN json_build_object('success', true, 'already_claimed', false, 'streak', v_new_streak, 'bonus', v_bonus);
END $function$
;

CREATE OR REPLACE FUNCTION public.cleanup_stale_open_games()
 RETURNS integer
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ SELECT 0; $function$
;

CREATE OR REPLACE FUNCTION public.create_game(_max_players integer, _stake numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid UUID := auth.uid(); v_balance NUMERIC; v_game_id UUID;
  v_commission NUMERIC; v_paused BOOLEAN; v_banned BOOLEAN; v_code TEXT; v_name text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  PERFORM public.cleanup_stale_open_games();
  SELECT paused INTO v_paused FROM public.app_settings WHERE id=1;
  IF COALESCE(v_paused,FALSE) THEN RAISE EXCEPTION 'Application en pause'; END IF;
  SELECT banned, pseudo INTO v_banned, v_name FROM public.profiles WHERE id=v_uid;
  IF COALESCE(v_banned,FALSE) THEN RAISE EXCEPTION 'Compte banni'; END IF;
  IF _max_players NOT BETWEEN 2 AND 4 THEN RAISE EXCEPTION 'Joueurs invalides'; END IF;
  IF _stake < 0 THEN RAISE EXCEPTION 'Mise invalide'; END IF;
  SELECT balance_ar INTO v_balance FROM public.profiles WHERE id = v_uid FOR UPDATE;
  IF v_balance < _stake THEN RAISE EXCEPTION 'Solde insuffisant'; END IF;
  SELECT game_commission_pct INTO v_commission FROM public.app_settings WHERE id=1;
  v_code := public._gen_room_code();
  INSERT INTO public.ludo_games(host_id, max_players, stake, pot, commission_pct, room_code)
    VALUES (v_uid, _max_players, _stake, _stake, COALESCE(v_commission,10), v_code)
    RETURNING id INTO v_game_id;
  UPDATE public.profiles SET balance_ar = balance_ar - _stake WHERE id = v_uid;
  INSERT INTO public.transactions(user_id,type,amount,ref_id,note) VALUES (v_uid,'stake',-_stake,v_game_id,'Mise création partie');
  INSERT INTO public.ludo_participants(game_id,user_id,slot,color,display_name)
    VALUES (v_game_id, v_uid, 0, 'red', v_name);
  RETURN v_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.create_private_game(_max_players integer, _stake numeric, _mode text DEFAULT 'classic'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid UUID := auth.uid(); v_balance NUMERIC; v_game_id UUID;
  v_commission NUMERIC; v_paused BOOLEAN; v_banned BOOLEAN; v_code TEXT; v_name text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  PERFORM public.cleanup_stale_open_games();
  SELECT paused INTO v_paused FROM public.app_settings WHERE id=1;
  IF COALESCE(v_paused,FALSE) THEN RAISE EXCEPTION 'Application en pause'; END IF;
  SELECT banned, pseudo INTO v_banned, v_name FROM public.profiles WHERE id=v_uid;
  IF COALESCE(v_banned,FALSE) THEN RAISE EXCEPTION 'Compte banni'; END IF;
  IF _max_players NOT BETWEEN 2 AND 4 THEN RAISE EXCEPTION 'Joueurs invalides'; END IF;
  IF _stake < 0 THEN RAISE EXCEPTION 'Mise invalide'; END IF;
  SELECT balance_ar INTO v_balance FROM public.profiles WHERE id = v_uid FOR UPDATE;
  IF v_balance < _stake THEN RAISE EXCEPTION 'Solde insuffisant'; END IF;
  SELECT game_commission_pct INTO v_commission FROM public.app_settings WHERE id=1;
  v_code := public._gen_room_code();
  INSERT INTO public.ludo_games(host_id, max_players, stake, pot, commission_pct, room_code, is_private, mode)
    VALUES (v_uid, _max_players, _stake, _stake, COALESCE(v_commission,10), v_code, TRUE, COALESCE(_mode,'classic'))
    RETURNING id INTO v_game_id;
  UPDATE public.profiles SET balance_ar = balance_ar - _stake WHERE id = v_uid;
  INSERT INTO public.transactions(user_id,type,amount,ref_id,note) VALUES (v_uid,'stake',-_stake,v_game_id,'Mise création partie privée');
  INSERT INTO public.ludo_participants(game_id,user_id,slot,color,display_name)
    VALUES (v_game_id, v_uid, 0, 'red', v_name);
  RETURN v_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.create_public_game(_max_players integer, _stake numeric, _mode text DEFAULT 'classic'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_balance numeric; v_id uuid; v_mode text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  v_mode := CASE WHEN _mode = 'fast' THEN 'fast' ELSE 'classic' END;
  IF _stake > 0 THEN
    SELECT balance_ar INTO v_balance FROM public.profiles WHERE id = v_uid FOR UPDATE;
    IF v_balance < _stake THEN RAISE EXCEPTION 'Solde insuffisant'; END IF;
    UPDATE public.profiles SET balance_ar = balance_ar - _stake WHERE id = v_uid;
    INSERT INTO public.transactions(user_id, type, amount, note) VALUES (v_uid, 'ludo_stake', -_stake, 'Mise Ludo');
  END IF;
  INSERT INTO public.ludo_games(host_id, max_players, stake, status, is_private, pot, mode)
    VALUES (v_uid, _max_players, _stake, 'open', false, _stake, v_mode) RETURNING id INTO v_id;
  INSERT INTO public.ludo_participants(game_id, user_id, slot, color, display_name)
    SELECT v_id, v_uid, 0, 'red', pseudo FROM public.profiles WHERE id = v_uid;
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.credit_user_balance(_user_id uuid, _amount numeric, _type text, _ref_id uuid DEFAULT NULL::uuid, _note text DEFAULT NULL::text, _meta jsonb DEFAULT NULL::jsonb)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE _new_balance NUMERIC; _is_bot BOOLEAN;
BEGIN
  IF _amount IS NULL OR _amount <= 0 THEN RAISE EXCEPTION 'credit: montant invalide (%)', _amount; END IF;
  SELECT is_bot INTO _is_bot FROM public.profiles WHERE id = _user_id;
  IF _is_bot THEN RETURN 0; END IF;
  UPDATE public.profiles SET balance_ar = balance_ar + _amount
  WHERE id = _user_id RETURNING balance_ar INTO _new_balance;
  IF _new_balance IS NULL THEN RAISE EXCEPTION 'Utilisateur introuvable %', _user_id; END IF;
  INSERT INTO public.transactions (user_id, amount, type, ref_id, note, meta)
  VALUES (_user_id, _amount, _type, _ref_id, _note, COALESCE(_meta, '{}'::jsonb));
  RETURN _new_balance;
END; $function$
;

CREATE OR REPLACE FUNCTION public.debit_user_balance(_user_id uuid, _amount numeric, _type text, _ref_id uuid DEFAULT NULL::uuid, _note text DEFAULT NULL::text, _meta jsonb DEFAULT NULL::jsonb)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE _new_balance NUMERIC; _is_bot BOOLEAN;
BEGIN
  IF _amount IS NULL OR _amount <= 0 THEN RAISE EXCEPTION 'debit: montant invalide (%)', _amount; END IF;
  SELECT is_bot INTO _is_bot FROM public.profiles WHERE id = _user_id;
  IF _is_bot THEN RETURN 0; END IF;
  UPDATE public.profiles SET balance_ar = balance_ar - _amount
  WHERE id = _user_id AND balance_ar >= _amount
  RETURNING balance_ar INTO _new_balance;
  IF _new_balance IS NULL THEN RAISE EXCEPTION 'Solde insuffisant' USING ERRCODE = 'P0001'; END IF;
  INSERT INTO public.transactions (user_id, amount, type, ref_id, note, meta)
  VALUES (_user_id, -_amount, _type, _ref_id, _note, COALESCE(_meta, '{}'::jsonb));
  RETURN _new_balance;
END; $function$
;

CREATE OR REPLACE FUNCTION public.delete_my_account()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  BEGIN UPDATE public.profiles SET pseudo='Compte supprimé', avatar_url=NULL, balance_ar=0, is_banned=true WHERE id = v_uid; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN UPDATE public.ludo_games     SET winner_id = NULL WHERE winner_id = v_uid; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN UPDATE public.domino_games   SET winner_id = NULL WHERE winner_id = v_uid; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN UPDATE public.fanorona_games SET winner_id = NULL WHERE winner_id = v_uid; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN UPDATE public.rami_games     SET winner_id = NULL WHERE winner_id = v_uid; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN UPDATE public.chess_games    SET winner_id = NULL WHERE winner_id = v_uid; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN UPDATE public.chess_games    SET white_id  = NULL WHERE white_id  = v_uid; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN UPDATE public.chess_games    SET black_id  = NULL WHERE black_id  = v_uid; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN UPDATE public.profiles       SET referred_by = NULL WHERE referred_by = v_uid; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN DELETE FROM auth.users WHERE id = v_uid; EXCEPTION WHEN OTHERS THEN NULL; END;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.domino_add_bot(_game_id uuid, _bot_name text DEFAULT 'Bot'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_is_admin boolean := public.is_admin();
  g public.domino_games%ROWTYPE;
  v_count int;
  v_slot int;
  v_bot_names text[] := ARRAY['Bot Rija','Bot Naina','Bot Hery','Bot Voara'];
  v_name text;
  v_ready_count int;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Connexion requise'; END IF;
  SELECT * INTO g FROM public.domino_games WHERE id = _game_id FOR UPDATE;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  IF g.status <> 'open' THEN RAISE EXCEPTION 'La partie a déjà commencé'; END IF;

  IF NOT v_is_admin THEN
    IF COALESCE(g.stake, 0) > 0 THEN
      RAISE EXCEPTION 'Bots réservés aux parties gratuites';
    END IF;
    IF g.host_id <> v_uid
       AND NOT EXISTS (SELECT 1 FROM public.domino_participants WHERE game_id=_game_id AND user_id=v_uid) THEN
      RAISE EXCEPTION 'Rejoignez la partie pour ajouter un bot';
    END IF;
  END IF;

  SELECT count(*) INTO v_count FROM public.domino_participants WHERE game_id=_game_id;
  IF v_count >= g.max_players THEN RAISE EXCEPTION 'Partie pleine'; END IF;

  v_slot := v_count;
  v_name := COALESCE(NULLIF(trim(_bot_name), ''), v_bot_names[LEAST(v_slot + 1, array_length(v_bot_names, 1))]);

  INSERT INTO public.domino_participants(
    game_id, user_id, slot, display_name, ready, is_bot, bot_name, bot_intelligence
  ) VALUES (_game_id, NULL, v_slot, v_name, TRUE, TRUE, v_name, 70);

  SELECT count(*), count(*) FILTER (WHERE ready)
    INTO v_count, v_ready_count
    FROM public.domino_participants
   WHERE game_id = _game_id;

  IF v_count = g.max_players AND v_ready_count = g.max_players THEN
    PERFORM public._domino_start(_game_id);
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.domino_create(_stake numeric, _max integer, _private boolean, _mode text DEFAULT 'classic'::text, _commission numeric DEFAULT 10)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_balance numeric;
  v_code text;
  v_id uuid;
  v_name text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  IF _max NOT BETWEEN 2 AND 4 THEN RAISE EXCEPTION 'invalid max_players'; END IF;
  IF _stake < 0 THEN RAISE EXCEPTION 'invalid stake'; END IF;

  SELECT balance_ar, pseudo INTO v_balance, v_name FROM public.profiles WHERE id = v_uid;
  IF v_balance IS NULL OR v_balance < _stake THEN RAISE EXCEPTION 'insufficient balance'; END IF;

  IF _private THEN
    v_code := upper(substring(md5(random()::text||clock_timestamp()::text) from 1 for 6));
  END IF;

  INSERT INTO public.domino_games(host_id, max_players, stake, pot, commission_pct, is_private, room_code, mode, state)
  VALUES (v_uid, _max, _stake, _stake, _commission, _private, v_code, _mode, public._domino_init_state())
  RETURNING id INTO v_id;

  UPDATE public.profiles SET balance_ar = balance_ar - _stake WHERE id = v_uid;
  INSERT INTO public.transactions(user_id, type, amount, ref_id, note) VALUES (v_uid, 'domino_stake', -_stake, v_id, 'Create domino game');

  INSERT INTO public.domino_participants(game_id, user_id, slot, display_name) VALUES (v_id, v_uid, 0, COALESCE(v_name,'Player'));
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.domino_create(_stake numeric, _max integer, _private boolean, _mode text DEFAULT 'classic'::text, _commission numeric DEFAULT 10, _target_score integer DEFAULT 0)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_balance numeric;
  v_code text;
  v_id uuid;
  v_name text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  IF _max NOT BETWEEN 2 AND 4 THEN RAISE EXCEPTION 'invalid max_players'; END IF;
  IF _stake < 0 THEN RAISE EXCEPTION 'invalid stake'; END IF;
  IF _target_score < 0 OR _target_score > 1000 THEN RAISE EXCEPTION 'invalid target_score'; END IF;

  SELECT balance_ar, pseudo INTO v_balance, v_name FROM public.profiles WHERE id = v_uid;
  IF v_balance IS NULL OR v_balance < _stake THEN RAISE EXCEPTION 'insufficient balance'; END IF;

  IF _private THEN
    v_code := upper(substring(md5(random()::text||clock_timestamp()::text) from 1 for 6));
  END IF;

  INSERT INTO public.domino_games(host_id, max_players, stake, pot, commission_pct, is_private, room_code, mode, target_score, state)
  VALUES (v_uid, _max, _stake, _stake, _commission, _private, v_code, _mode, _target_score, public._domino_init_state())
  RETURNING id INTO v_id;

  UPDATE public.profiles SET balance_ar = balance_ar - _stake WHERE id = v_uid;
  INSERT INTO public.transactions(user_id, type, amount, ref_id, note) VALUES (v_uid, 'domino_stake', -_stake, v_id, 'Create domino game');
  INSERT INTO public.domino_participants(game_id, user_id, slot, display_name) VALUES (v_id, v_uid, 0, COALESCE(v_name,'Player'));
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.domino_create(_stake numeric, _max integer, _private boolean, _mode text DEFAULT 'classic'::text, _commission numeric DEFAULT 10, _target_score integer DEFAULT 0, _draw_mode text DEFAULT 'with'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_balance numeric; v_code text; v_id uuid; v_name text; v_state jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  IF _max NOT BETWEEN 2 AND 3 THEN RAISE EXCEPTION 'invalid max_players (2-3)'; END IF;
  IF _stake < 0 THEN RAISE EXCEPTION 'invalid stake'; END IF;
  IF _target_score < 0 OR _target_score > 1000 THEN RAISE EXCEPTION 'invalid target_score'; END IF;
  IF _draw_mode NOT IN ('with','without') THEN RAISE EXCEPTION 'invalid draw_mode'; END IF;

  SELECT balance_ar, pseudo INTO v_balance, v_name FROM public.profiles WHERE id = v_uid;
  IF v_balance IS NULL OR v_balance < _stake THEN RAISE EXCEPTION 'insufficient balance'; END IF;

  IF _private THEN
    v_code := upper(substring(md5(random()::text||clock_timestamp()::text) from 1 for 6));
  END IF;

  v_state := public._domino_init_state();
  v_state := jsonb_set(v_state, '{draw_mode}', to_jsonb(_draw_mode), true);

  INSERT INTO public.domino_games(host_id, max_players, stake, pot, commission_pct, is_private, room_code, mode, target_score, state)
  VALUES (v_uid, _max, _stake, _stake, _commission, _private, v_code, _mode, _target_score, v_state)
  RETURNING id INTO v_id;

  UPDATE public.profiles SET balance_ar = balance_ar - _stake WHERE id = v_uid;
  INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
    VALUES (v_uid, 'domino_stake', -_stake, v_id, 'Create domino game');
  INSERT INTO public.domino_participants(game_id, user_id, slot, display_name)
    VALUES (v_id, v_uid, 0, COALESCE(v_name,'Player'));
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.domino_create(_stake numeric, _max integer, _private boolean, _mode text DEFAULT 'classic'::text, _commission numeric DEFAULT 10, _target_score integer DEFAULT 0, _draw_mode text DEFAULT 'with'::text, _first_tile_rule text DEFAULT 'libre'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_balance numeric; v_code text; v_id uuid; v_name text; v_state jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  IF _max NOT BETWEEN 2 AND 3 THEN RAISE EXCEPTION 'invalid max_players (2-3)'; END IF;
  IF _stake < 0 THEN RAISE EXCEPTION 'invalid stake'; END IF;
  IF _target_score < 0 OR _target_score > 1000 THEN RAISE EXCEPTION 'invalid target_score'; END IF;
  IF _draw_mode NOT IN ('with','without') THEN RAISE EXCEPTION 'invalid draw_mode'; END IF;
  IF _first_tile_rule NOT IN ('libre','under6') THEN RAISE EXCEPTION 'invalid first_tile_rule'; END IF;

  SELECT balance_ar, pseudo INTO v_balance, v_name FROM public.profiles WHERE id = v_uid;
  IF v_balance IS NULL OR v_balance < _stake THEN RAISE EXCEPTION 'insufficient balance'; END IF;

  IF _private THEN
    v_code := upper(substring(md5(random()::text||clock_timestamp()::text) from 1 for 6));
  END IF;

  v_state := public._domino_init_state();
  v_state := jsonb_set(v_state, '{draw_mode}', to_jsonb(_draw_mode), true);
  v_state := jsonb_set(v_state, '{first_tile_rule}', to_jsonb(_first_tile_rule), true);

  INSERT INTO public.domino_games(host_id, max_players, stake, pot, commission_pct, is_private, room_code, mode, target_score, state, first_tile_rule)
  VALUES (v_uid, _max, _stake, _stake, _commission, _private, v_code, _mode, _target_score, v_state, _first_tile_rule)
  RETURNING id INTO v_id;

  UPDATE public.profiles SET balance_ar = balance_ar - _stake WHERE id = v_uid;
  INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
    VALUES (v_uid, 'domino_stake', -_stake, v_id, 'Create domino game');
  INSERT INTO public.domino_participants(game_id, user_id, slot, display_name)
    VALUES (v_id, v_uid, 0, COALESCE(v_name,'Player'));
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.domino_forfeit(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  g record;
  my_slot int;
  remaining int;
  last_slot int;
  humans_left int;
BEGIN
  SELECT * INTO g FROM public.domino_games WHERE id = _game_id FOR UPDATE;
  IF g.status NOT IN ('open','playing') THEN RETURN; END IF;
  SELECT slot INTO my_slot FROM public.domino_participants WHERE game_id = _game_id AND user_id = v_uid;
  IF my_slot IS NULL THEN RETURN; END IF;
  UPDATE public.domino_participants SET forfeited = true WHERE game_id = _game_id AND user_id = v_uid;

  IF g.status = 'open' THEN
    UPDATE public.profiles p SET balance_ar = balance_ar + g.stake
      FROM public.domino_participants pp
     WHERE pp.game_id = _game_id AND pp.user_id = p.id AND COALESCE(pp.is_bot,false) = false;
    INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
      SELECT user_id, 'domino_refund', g.stake, _game_id, 'Game cancelled'
        FROM public.domino_participants
       WHERE game_id = _game_id AND COALESCE(is_bot,false) = false;
    UPDATE public.domino_games SET status = 'cancelled', finished_at = now() WHERE id = _game_id;
    humans_left := public._domino_active_humans(_game_id);
    IF humans_left = 0 THEN PERFORM public._domino_purge(_game_id); END IF;
    RETURN;
  END IF;

  humans_left := public._domino_active_humans(_game_id);
  IF humans_left = 0 THEN
    UPDATE public.domino_games SET status = 'cancelled', finished_at = now() WHERE id = _game_id;
    PERFORM public._domino_purge(_game_id);
    RETURN;
  END IF;

  SELECT count(*) INTO remaining FROM public.domino_participants WHERE game_id = _game_id AND forfeited = false;
  IF remaining <= 1 THEN
    SELECT slot INTO last_slot FROM public.domino_participants WHERE game_id = _game_id AND forfeited = false LIMIT 1;
    IF last_slot IS NOT NULL THEN
      PERFORM public._domino_finalize(_game_id, last_slot);
    ELSE
      UPDATE public.domino_games SET status='cancelled', finished_at=now() WHERE id = _game_id;
      PERFORM public._domino_purge(_game_id);
    END IF;
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.domino_join(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  g record;
  v_balance numeric;
  v_name text;
  v_slot int;
  v_count int;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO g FROM public.domino_games WHERE id = _game_id FOR UPDATE;
  IF g.id IS NULL OR g.status <> 'open' THEN RAISE EXCEPTION 'game not joinable'; END IF;
  IF EXISTS(SELECT 1 FROM public.domino_participants WHERE game_id = _game_id AND user_id = v_uid) THEN RETURN; END IF;
  SELECT balance_ar, pseudo INTO v_balance, v_name FROM public.profiles WHERE id = v_uid;
  IF v_balance < g.stake THEN RAISE EXCEPTION 'insufficient balance'; END IF;

  SELECT count(*) INTO v_count FROM public.domino_participants WHERE game_id = _game_id;
  IF v_count >= g.max_players THEN RAISE EXCEPTION 'full'; END IF;
  v_slot := v_count;

  INSERT INTO public.domino_participants(game_id, user_id, slot, display_name) VALUES (_game_id, v_uid, v_slot, COALESCE(v_name,'Player'));
  UPDATE public.profiles SET balance_ar = balance_ar - g.stake WHERE id = v_uid;
  INSERT INTO public.transactions(user_id, type, amount, ref_id, note) VALUES (v_uid, 'domino_stake', -g.stake, _game_id, 'Join domino game');
  UPDATE public.domino_games SET pot = pot + g.stake WHERE id = _game_id;

  -- No auto-start: wait for all participants to mark themselves ready (domino_set_ready).
END $function$
;

CREATE OR REPLACE FUNCTION public.domino_join_code(_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g_id uuid;
BEGIN
  SELECT id INTO g_id FROM public.domino_games WHERE room_code = upper(_code) AND status = 'open';
  IF g_id IS NULL THEN RAISE EXCEPTION 'invalid code'; END IF;
  PERFORM public.domino_join(g_id);
  RETURN g_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.domino_play(_game_id uuid, _move jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_slot integer;
  v_turn_secs integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth required';
  END IF;

  SELECT slot INTO v_slot
    FROM public.domino_participants
   WHERE game_id = _game_id
     AND user_id = v_uid
     AND COALESCE(forfeited, false) = false;

  IF v_slot IS NULL THEN
    RAISE EXCEPTION 'not a player';
  END IF;

  PERFORM public._domino_play_as(_game_id, v_slot, _move);

  IF COALESCE(_move->>'action', '') = 'draw' THEN
    SELECT COALESCE(turn_timer_seconds, 30) INTO v_turn_secs
      FROM public.game_configs
     WHERE slug = 'domino';

    UPDATE public.domino_games
       SET turn_deadline = now() + (COALESCE(v_turn_secs, 30) || ' seconds')::interval
     WHERE id = _game_id
       AND status = 'playing'
       AND current_turn = v_slot;
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.domino_play_and_bot(_game_id uuid, _move jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  PERFORM public.domino_play(_game_id, _move);
  PERFORM public._domino_bot_step(_game_id);
END $function$
;

-- ═══════════ 0007_functions_09.sql ═══════════
-- 0007_functions_09.sql
-- Fonctions et procédures (9/12)

CREATE OR REPLACE FUNCTION public.domino_set_ready(_game_id uuid, _ready boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_status text;
  v_count int;
  v_max int;
  v_ready_count int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.domino_participants
     SET ready = COALESCE(_ready, false)
   WHERE game_id = _game_id AND user_id = v_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not a participant';
  END IF;

  SELECT status::text, max_players
    INTO v_status, v_max
    FROM public.domino_games
   WHERE id = _game_id
   FOR UPDATE;

  IF v_status <> 'open' THEN
    RETURN;
  END IF;

  SELECT count(*), count(*) FILTER (WHERE ready)
    INTO v_count, v_ready_count
    FROM public.domino_participants
   WHERE game_id = _game_id;

  IF v_count = v_max AND v_ready_count = v_max THEN
    PERFORM public._domino_start(_game_id);
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.domino_start_solo_bot(_max_players integer DEFAULT 2, _difficulty text DEFAULT 'medium'::text, _target_score integer DEFAULT 100, _draw_mode text DEFAULT 'with'::text, _first_tile_rule text DEFAULT 'libre'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_game_id uuid;
  v_code text;
  v_name text;
  v_intel int;
  v_paused boolean;
  v_banned boolean;
  v_commission numeric;
  v_slot int;
  v_bot_names text[] := ARRAY['Bot Rija','Bot Naina','Bot Hery','Bot Voara'];
  v_init_state jsonb;
BEGIN
  PERFORM public._assert_solo_bot_enabled();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF _max_players NOT BETWEEN 2 AND 4 THEN RAISE EXCEPTION 'Joueurs invalides (2-4)'; END IF;
  IF _draw_mode NOT IN ('with','without') THEN _draw_mode := 'with'; END IF;
  IF _first_tile_rule NOT IN ('libre','under6') THEN _first_tile_rule := 'libre'; END IF;

  SELECT paused INTO v_paused FROM public.app_settings WHERE id=1;
  IF COALESCE(v_paused,false) THEN RAISE EXCEPTION 'Application en pause'; END IF;

  SELECT banned, pseudo INTO v_banned, v_name FROM public.profiles WHERE id=v_uid;
  IF COALESCE(v_banned,false) THEN RAISE EXCEPTION 'Compte banni'; END IF;

  CASE lower(_difficulty)
    WHEN 'easy'   THEN v_intel := 30;
    WHEN 'hard'   THEN v_intel := 95;
    ELSE               v_intel := 70;
  END CASE;

  SELECT COALESCE(game_commission_pct,10) INTO v_commission FROM public.app_settings WHERE id=1;
  v_code := public._gen_room_code();

  v_init_state := jsonb_build_object(
    'phase','waiting',
    'draw_mode', _draw_mode,
    'first_tile_rule', _first_tile_rule,
    'round', 0,
    'scores', '{}'::jsonb
  );

  INSERT INTO public.domino_games(
    host_id, max_players, stake, pot, commission_pct, room_code, is_private, mode,
    status, started_at, target_score, first_tile_rule, state
  )
  VALUES (
    v_uid, _max_players, 0, 0, v_commission, v_code, true, 'classic',
    'playing', now(), COALESCE(_target_score, 100), _first_tile_rule, v_init_state
  )
  RETURNING id INTO v_game_id;

  INSERT INTO public.domino_participants(game_id, user_id, slot, display_name, ready, is_bot)
    VALUES (v_game_id, v_uid, 0, v_name, true, false);

  FOR v_slot IN 1.._max_players - 1 LOOP
    INSERT INTO public.domino_participants(
      game_id, user_id, slot, display_name, ready, is_bot, bot_name, bot_intelligence
    ) VALUES (
      v_game_id, NULL, v_slot, v_bot_names[v_slot], true, true, v_bot_names[v_slot], v_intel
    );
  END LOOP;

  PERFORM public._domino_next_round(v_game_id);

  RETURN v_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.domino_tick(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g record;
  cur_uid uuid;
  _cfg record;
  _skips int;
  _next int;
  remaining int;
  last_slot int;
  _break_until timestamptz;
  _reveal_until timestamptz;
  _deal_until timestamptz;
  required_slot int;
  board_empty boolean;
  cur_is_bot boolean;
BEGIN
  SELECT * INTO g FROM public.domino_games WHERE id = _game_id FOR UPDATE;
  IF g IS NULL OR g.status <> 'playing' THEN RETURN; END IF;

  IF (g.state->>'phase') = 'dealing' THEN
    _deal_until := NULLIF(g.state->>'deal_until','')::timestamptz;
    IF _deal_until IS NULL OR _deal_until <= now() THEN
      PERFORM public._domino_place_first(_game_id);
      PERFORM public._domino_bot_step(_game_id);
    END IF;
    RETURN;
  END IF;

  IF (g.state->>'phase') = 'reveal' THEN
    _reveal_until := NULLIF(g.state->>'reveal_until','')::timestamptz;
    IF _reveal_until IS NOT NULL AND _reveal_until <= now() THEN
      UPDATE public.domino_games
         SET state = jsonb_set(g.state, '{phase}', '"break"'::jsonb)
       WHERE id = _game_id;
    END IF;
    RETURN;
  END IF;

  IF (g.state->>'phase') = 'break' THEN
    _break_until := NULLIF(g.state->>'break_until','')::timestamptz;
    IF _break_until IS NOT NULL AND _break_until <= now() THEN
      PERFORM public._domino_next_round(_game_id);
      PERFORM public._domino_bot_step(_game_id);
    END IF;
    RETURN;
  END IF;

  SELECT * INTO _cfg FROM public._game_cfg('domino');
  board_empty := jsonb_array_length(COALESCE(g.state->'board', '[]'::jsonb)) = 0;
  required_slot := public._domino_required_starter_slot(_game_id, g.state);

  IF board_empty AND required_slot IS NOT NULL AND required_slot <> g.current_turn THEN
    UPDATE public.domino_games
       SET current_turn = required_slot,
           turn_deadline = now() + (_cfg.turn_timer_seconds || ' seconds')::interval
     WHERE id = _game_id;
    PERFORM public._domino_bot_step(_game_id);
    RETURN;
  END IF;

  SELECT COALESCE(dp.is_bot, false) INTO cur_is_bot
    FROM public.domino_participants dp
   WHERE dp.game_id = _game_id
     AND dp.slot = g.current_turn
     AND dp.forfeited = false;

  IF COALESCE(cur_is_bot, false) THEN
    PERFORM public._domino_bot_step(_game_id);
    RETURN;
  END IF;

  IF g.turn_deadline IS NULL OR g.turn_deadline > now() THEN RETURN; END IF;

  SELECT user_id INTO cur_uid
    FROM public.domino_participants
   WHERE game_id = _game_id
     AND slot = g.current_turn
     AND forfeited = false;

  IF cur_uid IS NULL THEN
    _next := public._domino_next_playable_slot(_game_id, g.current_turn, g.state);
    IF _next IS NOT NULL THEN
      UPDATE public.domino_games
         SET current_turn = _next,
             turn_deadline = now() + (_cfg.turn_timer_seconds || ' seconds')::interval
       WHERE id = _game_id;
      PERFORM public._domino_bot_step(_game_id);
    END IF;
    RETURN;
  END IF;

  -- Le joueur n'a rien joué : s'il devait piocher, on pioche à sa place
  -- jusqu'à obtenir une tuile jouable, et on lui rend son temps.
  IF public._domino_auto_draw(_game_id) THEN
    RETURN;
  END IF;
  SELECT * INTO g FROM public.domino_games WHERE id = _game_id;

  _skips := COALESCE((g.turn_skips->>cur_uid::text)::int, 0) + 1;

  IF _skips >= _cfg.max_turn_skips THEN
    UPDATE public.domino_participants
       SET forfeited = true
     WHERE game_id = _game_id
       AND user_id = cur_uid;

    SELECT count(*) INTO remaining
      FROM public.domino_participants
     WHERE game_id = _game_id
       AND forfeited = false;

    IF remaining <= 1 THEN
      SELECT slot INTO last_slot
        FROM public.domino_participants
       WHERE game_id = _game_id
         AND forfeited = false
       LIMIT 1;

      IF last_slot IS NOT NULL THEN
        PERFORM public._domino_finalize(_game_id, last_slot);
      ELSE
        UPDATE public.domino_games SET status='cancelled', finished_at=now() WHERE id = _game_id;
      END IF;
      RETURN;
    END IF;

    g.turn_skips := jsonb_set(COALESCE(g.turn_skips,'{}'::jsonb), ARRAY[cur_uid::text], to_jsonb(_skips), true);
    g.state := jsonb_set(g.state, ARRAY['hands', g.current_turn::text], '[]'::jsonb, true);
    required_slot := public._domino_required_starter_slot(_game_id, g.state);

    IF board_empty AND required_slot IS NOT NULL THEN
      UPDATE public.domino_games
         SET state = g.state,
             turn_skips = g.turn_skips,
             current_turn = required_slot,
             turn_deadline = now() + (_cfg.turn_timer_seconds || ' seconds')::interval
       WHERE id = _game_id;
      PERFORM public._domino_bot_step(_game_id);
      RETURN;
    END IF;
  ELSE
    g.turn_skips := jsonb_set(COALESCE(g.turn_skips,'{}'::jsonb), ARRAY[cur_uid::text], to_jsonb(_skips), true);

    IF board_empty AND required_slot IS NOT NULL THEN
      UPDATE public.domino_games
         SET turn_skips = g.turn_skips,
             current_turn = required_slot,
             turn_deadline = now() + (_cfg.turn_timer_seconds || ' seconds')::interval
       WHERE id = _game_id;
      PERFORM public._domino_bot_step(_game_id);
      RETURN;
    END IF;

    UPDATE public.domino_games SET turn_skips = g.turn_skips WHERE id = _game_id;
  END IF;

  _next := public._domino_next_playable_slot(_game_id, g.current_turn, g.state);
  IF _next IS NULL THEN
    _next := public._domino_lowest_pip_slot(_game_id, g.state);
    PERFORM public._domino_end_round(_game_id, _next);
    RETURN;
  END IF;

  UPDATE public.domino_games
     SET current_turn = _next,
         turn_deadline = now() + (_cfg.turn_timer_seconds || ' seconds')::interval
   WHERE id = _game_id;

  PERFORM public._domino_bot_step(_game_id);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.domino_tick_all()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  g_id uuid;
BEGIN
  FOR g_id IN
    SELECT g.id
      FROM public.domino_games g
     WHERE g.status = 'playing'
       AND (
         (g.turn_deadline IS NOT NULL AND g.turn_deadline <= now())
         OR (g.state->>'phase' = 'dealing' AND COALESCE(NULLIF(g.state->>'deal_until','')::timestamptz, now()) <= now())
         OR (g.state->>'phase' = 'reveal'  AND NULLIF(g.state->>'reveal_until','')::timestamptz <= now())
         OR (g.state->>'phase' = 'break'   AND NULLIF(g.state->>'break_until','')::timestamptz <= now())
         OR (
           EXISTS (
             SELECT 1
               FROM public.domino_participants p
              WHERE p.game_id = g.id
                AND p.slot = g.current_turn
                AND p.forfeited = false
                AND p.is_bot = true
           )
           AND (
             NULLIF(g.state->>'bot_think_until','')::timestamptz IS NULL
             OR NULLIF(g.state->>'bot_think_until','')::timestamptz <= now()
             OR COALESCE(NULLIF(g.state->>'bot_locked_slot','null')::int, -1) IS DISTINCT FROM g.current_turn
           )
         )
       )
  LOOP
    BEGIN
      PERFORM public.domino_tick(g_id);
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fanorona_add_bot(_game_id uuid, _bot_name text DEFAULT 'Bot'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  g record;
  v_bot_id uuid := gen_random_uuid();
  v_bot_mail text;
  v_slot int;
  v_is_admin boolean;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO g FROM public.fanorona_games WHERE id = _game_id FOR UPDATE;
  IF g IS NULL THEN RAISE EXCEPTION 'game not found'; END IF;
  IF g.status <> 'open' THEN RAISE EXCEPTION 'game not open'; END IF;

  v_is_admin := public.has_role(v_uid, 'admin'::app_role);
  IF NOT v_is_admin AND g.host_id <> v_uid THEN
    RAISE EXCEPTION 'only host may add bots';
  END IF;
  IF NOT v_is_admin AND g.stake > 0 THEN
    RAISE EXCEPTION 'bots only allowed in free games';
  END IF;
  IF (SELECT count(*) FROM public.fanorona_participants WHERE game_id = _game_id) >= 2 THEN
    RAISE EXCEPTION 'game full';
  END IF;

  v_bot_mail := 'fanoronabot_' || v_bot_id::text || '@bot.lalaomada.internal';
  INSERT INTO auth.users (
    id, instance_id, aud, role,
    email, encrypted_password, email_confirmed_at,
    raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token, email_change, email_change_token_new
  ) VALUES (
    v_bot_id, '00000000-0000-0000-0000-000000000000',
    'authenticated','authenticated',
    v_bot_mail, crypt(gen_random_uuid()::text, gen_salt('bf')), now(),
    jsonb_build_object('pseudo', _bot_name, 'is_bot', true),
    now(), now(), '', '', '', ''
  );
  UPDATE public.profiles
     SET balance_ar = 0, pseudo = _bot_name, avatar_url = NULL, is_bot = true
   WHERE id = v_bot_id;

  SELECT COALESCE(MIN(s.slot),0) INTO v_slot
    FROM (SELECT 0 AS slot UNION SELECT 1) s
   WHERE s.slot NOT IN (SELECT slot FROM public.fanorona_participants WHERE game_id = _game_id);

  INSERT INTO public.fanorona_participants(game_id, user_id, slot, color, display_name, is_bot, ready)
  VALUES (_game_id, v_bot_id, v_slot,
          CASE WHEN v_slot = 0 THEN 'white' ELSE 'black' END,
          _bot_name, true, true);

  IF (SELECT count(*) FROM public.fanorona_participants WHERE game_id = _game_id) = 2 THEN
    UPDATE public.fanorona_games
       SET status = 'playing', started_at = now(), current_turn = 0,
           turn_deadline = now() + (COALESCE((SELECT turn_timer_seconds FROM public._game_cfg('fanorona')),60) || ' seconds')::interval
     WHERE id = _game_id;
  END IF;
  RETURN v_bot_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.fanorona_bot_play(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  g record;
  st jsonb; board jsonb;
  my_slot int; my_color int;
  v_cols int; v_rows int;
  is_bot boolean;
  i int; r int; c int; dr int; dc int; nr int; nc int; nidx int;
  is_strong boolean;
  lists jsonb;
  best_from int := -1; best_to int := -1; best_cap jsonb := '[]'::jsonb;
  best_count int := -1;
  chain_from_v int;
  visited jsonb; last_axis text; axis text;
  move_count int;
  cap_count int;
  first_move boolean;
  choose_cap jsonb;
BEGIN
  SELECT * INTO g FROM public.fanorona_games WHERE id = _game_id FOR UPDATE;
  IF g IS NULL OR g.status <> 'playing' THEN RETURN; END IF;

  my_slot := g.current_turn;
  SELECT COALESCE(fp.is_bot, false) INTO is_bot FROM public.fanorona_participants fp
    WHERE fp.game_id = _game_id AND fp.slot = my_slot;
  IF NOT COALESCE(is_bot, false) THEN RETURN; END IF;

  st := g.state; board := st -> 'board';
  v_cols := COALESCE(g.cols, 9); v_rows := COALESCE(g.rows, 5);
  my_color := CASE WHEN my_slot = 0 THEN 1 ELSE 2 END;
  move_count := COALESCE((st->>'move_count')::int, 0);
  visited := COALESCE(st->'visited', '[]'::jsonb);
  last_axis := NULLIF(st->>'last_axis', '');
  chain_from_v := CASE WHEN st->'chain_from' IS NULL OR st->'chain_from' = 'null'::jsonb
                       THEN NULL ELSE (st->>'chain_from')::int END;
  first_move := (move_count = 0);

  FOR i IN 0..(v_cols * v_rows - 1) LOOP
    IF chain_from_v IS NOT NULL AND i <> chain_from_v THEN CONTINUE; END IF;
    IF (board->i)::int <> my_color THEN CONTINUE; END IF;
    r := i / v_cols; c := i % v_cols;
    is_strong := ((r + c) % 2 = 0);
    FOR dr, dc IN
      SELECT a, b FROM (VALUES (-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)) v(a,b)
    LOOP
      IF NOT is_strong AND (dr <> 0 AND dc <> 0) THEN CONTINUE; END IF;
      nr := r + dr; nc := c + dc;
      IF nr < 0 OR nr >= v_rows OR nc < 0 OR nc >= v_cols THEN CONTINUE; END IF;
      nidx := nr * v_cols + nc;
      IF (board->nidx)::int <> 0 THEN CONTINUE; END IF;
      IF chain_from_v IS NOT NULL AND visited @> to_jsonb(nidx) THEN CONTINUE; END IF;
      axis := public._fanorona_axis(dr, dc);
      IF chain_from_v IS NOT NULL AND last_axis IS NOT NULL AND axis = last_axis THEN CONTINUE; END IF;

      lists := public._fanorona_capture_lists(board, my_color, i, nidx, v_cols, v_rows);
      choose_cap := NULL;
      IF jsonb_array_length(lists->'approach') > 0 THEN
        choose_cap := lists->'approach';
      END IF;
      IF NOT first_move AND jsonb_array_length(lists->'withdrawal') > COALESCE(jsonb_array_length(choose_cap),0) THEN
        choose_cap := lists->'withdrawal';
      END IF;

      cap_count := COALESCE(jsonb_array_length(choose_cap), 0);
      IF cap_count > best_count THEN
        best_count := cap_count;
        best_from := i; best_to := nidx;
        best_cap := COALESCE(choose_cap, '[]'::jsonb);
      END IF;
    END LOOP;
  END LOOP;

  IF best_from < 0 THEN
    PERFORM public.fanorona_play_as_bot(_game_id, jsonb_build_object('pass', true));
    RETURN;
  END IF;

  -- If we're in a chain and best move has 0 captures, pass instead
  IF chain_from_v IS NOT NULL AND best_count <= 0 THEN
    PERFORM public.fanorona_play_as_bot(_game_id, jsonb_build_object('pass', true));
    RETURN;
  END IF;

  PERFORM public.fanorona_play_as_bot(_game_id,
    jsonb_build_object('from', best_from, 'to', best_to, 'captured', best_cap));
END $function$
;

CREATE OR REPLACE FUNCTION public.fanorona_check_global_timeout(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g public.fanorona_games%ROWTYPE;
  loser_slot int;
  loser_user uuid;
  winner_user uuid;
BEGIN
  SELECT * INTO g FROM public.fanorona_games WHERE id = _game_id FOR UPDATE;
  IF NOT FOUND OR g.status <> 'playing' OR g.game_deadline IS NULL THEN RETURN; END IF;
  IF now() < g.game_deadline THEN RETURN; END IF;

  loser_slot := g.current_turn;
  SELECT user_id INTO loser_user FROM public.fanorona_participants WHERE game_id = _game_id AND slot = loser_slot;
  SELECT user_id INTO winner_user FROM public.fanorona_participants WHERE game_id = _game_id AND slot <> loser_slot LIMIT 1;

  UPDATE public.fanorona_games
     SET status = 'finished', winner_id = winner_user, finished_at = now()
   WHERE id = _game_id;

  IF winner_user IS NOT NULL AND g.pot > 0 THEN
    UPDATE public.profiles SET balance = COALESCE(balance,0) + g.pot WHERE user_id = winner_user;
    INSERT INTO public.transactions(user_id, kind, amount, meta)
      VALUES (winner_user, 'game_win', g.pot, jsonb_build_object('game','fanorona','game_id',_game_id,'reason','global_timeout'));
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fanorona_create(_stake numeric, _private boolean, _commission numeric DEFAULT 10)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_balance numeric;
  v_code text;
  v_id uuid;
  v_name text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  IF _stake < 0 THEN RAISE EXCEPTION 'invalid stake'; END IF;
  SELECT balance_ar, pseudo INTO v_balance, v_name FROM public.profiles WHERE id = v_uid;
  IF v_balance < _stake THEN RAISE EXCEPTION 'insufficient balance'; END IF;
  IF _private THEN v_code := upper(substring(md5(random()::text||clock_timestamp()::text) from 1 for 6)); END IF;

  INSERT INTO public.fanorona_games(host_id, stake, pot, commission_pct, is_private, room_code, state)
  VALUES (v_uid, _stake, _stake, _commission, _private, v_code,
    jsonb_build_object('phase','waiting','board', public._fanorona_init_board(), 'chain_from', null, 'chain_dirs', '[]'::jsonb))
  RETURNING id INTO v_id;

  UPDATE public.profiles SET balance_ar = balance_ar - _stake WHERE id = v_uid;
  INSERT INTO public.transactions(user_id, type, amount, ref_id, note) VALUES (v_uid, 'fanorona_stake', -_stake, v_id, 'Create fanorona');
  INSERT INTO public.fanorona_participants(game_id, user_id, slot, color, display_name) VALUES (v_id, v_uid, 0, 'white', COALESCE(v_name,'Player'));
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.fanorona_create(_stake numeric, _private boolean, _commission numeric DEFAULT 10, _variant text DEFAULT 'tsivy'::text, _mandatory_capture boolean DEFAULT true)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_balance numeric;
  v_code text;
  v_id uuid;
  v_name text;
  v_cols int; v_rows int;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  IF _stake < 0 THEN RAISE EXCEPTION 'invalid stake'; END IF;

  CASE _variant
    WHEN 'telo'  THEN v_cols := 3; v_rows := 3;
    WHEN 'dimy'  THEN v_cols := 5; v_rows := 5;
    WHEN 'tsivy' THEN v_cols := 9; v_rows := 5;
    ELSE v_cols := 9; v_rows := 5; _variant := 'tsivy';
  END CASE;

  SELECT balance_ar, pseudo INTO v_balance, v_name FROM public.profiles WHERE id = v_uid;
  IF v_balance < _stake THEN RAISE EXCEPTION 'insufficient balance'; END IF;
  IF _private THEN v_code := upper(substring(md5(random()::text||clock_timestamp()::text) from 1 for 6)); END IF;

  INSERT INTO public.fanorona_games(host_id, stake, pot, commission_pct, is_private, room_code, state, cols, rows, variant, mandatory_capture)
  VALUES (v_uid, _stake, _stake, _commission, _private, v_code,
    jsonb_build_object('phase','waiting','board', public._fanorona_init_board(v_cols, v_rows), 'chain_from', null, 'chain_dirs', '[]'::jsonb),
    v_cols, v_rows, _variant, COALESCE(_mandatory_capture, true))
  RETURNING id INTO v_id;

  UPDATE public.profiles SET balance_ar = balance_ar - _stake WHERE id = v_uid;
  INSERT INTO public.transactions(user_id, type, amount, ref_id, note) VALUES (v_uid, 'fanorona_stake', -_stake, v_id, 'Create fanorona');
  INSERT INTO public.fanorona_participants(game_id, user_id, slot, color, display_name) VALUES (v_id, v_uid, 0, 'white', COALESCE(v_name,'Player'));
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.fanorona_draw_finalize(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_g public.fanorona_games%ROWTYPE; v_starter uuid; v_other uuid; _cfg record;
        v_p0 uuid; v_p1 uuid;
BEGIN
  SELECT * INTO v_g FROM public.fanorona_games WHERE id=_game_id FOR UPDATE;
  IF v_g.id IS NULL OR v_g.status <> 'drawing' OR v_g.draw_result_color IS NULL THEN RETURN; END IF;
  -- NO time guard

  v_starter := CASE WHEN v_g.draw_result_color = 'w' THEN v_g.draw_white_by ELSE v_g.draw_black_by END;

  -- Assign slots: starter -> slot 0 (white), other -> slot 1 (black)
  SELECT user_id INTO v_p0 FROM public.fanorona_participants WHERE game_id=_game_id AND user_id = v_starter LIMIT 1;
  SELECT user_id INTO v_p1 FROM public.fanorona_participants WHERE game_id=_game_id AND user_id <> v_starter LIMIT 1;

  UPDATE public.fanorona_participants SET slot = 0, color = 'w' WHERE game_id=_game_id AND user_id = v_p0;
  UPDATE public.fanorona_participants SET slot = 1, color = 'b' WHERE game_id=_game_id AND user_id = v_p1;

  SELECT * INTO _cfg FROM public._game_cfg('fanorona');
  UPDATE public.fanorona_games
     SET status='playing',
         turn = 0,
         started_at = now(),
         turn_deadline = now() + (COALESCE(_cfg.turn_timer_seconds,60) || ' seconds')::interval
   WHERE id=_game_id AND status='drawing';
END; $function$
;

CREATE OR REPLACE FUNCTION public.fanorona_draw_pick_color(_game_id uuid, _color text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_g public.fanorona_games%ROWTYPE;
        v_other uuid; v_is_player boolean;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  IF _color NOT IN ('w','b') THEN RAISE EXCEPTION 'invalid color'; END IF;
  SELECT * INTO v_g FROM public.fanorona_games WHERE id=_game_id FOR UPDATE;
  IF v_g.id IS NULL OR v_g.status <> 'drawing' THEN RAISE EXCEPTION 'not drawing'; END IF;
  SELECT EXISTS(SELECT 1 FROM public.fanorona_participants WHERE game_id=_game_id AND user_id=v_uid) INTO v_is_player;
  IF NOT v_is_player THEN RAISE EXCEPTION 'not a player'; END IF;
  IF v_g.draw_result_color IS NOT NULL THEN RETURN; END IF;
  IF v_g.draw_white_by = v_uid OR v_g.draw_black_by = v_uid THEN RETURN; END IF;

  SELECT user_id INTO v_other FROM public.fanorona_participants
    WHERE game_id=_game_id AND user_id <> v_uid LIMIT 1;

  IF _color = 'w' THEN
    IF v_g.draw_white_by IS NOT NULL THEN RAISE EXCEPTION 'color taken'; END IF;
    UPDATE public.fanorona_games
       SET draw_white_by = v_uid,
           draw_black_by = COALESCE(draw_black_by, v_other)
     WHERE id=_game_id;
  ELSE
    IF v_g.draw_black_by IS NOT NULL THEN RAISE EXCEPTION 'color taken'; END IF;
    UPDATE public.fanorona_games
       SET draw_black_by = v_uid,
           draw_white_by = COALESCE(draw_white_by, v_other)
     WHERE id=_game_id;
  END IF;
END; $function$
;

CREATE OR REPLACE FUNCTION public.fanorona_draw_spin(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_g public.fanorona_games%ROWTYPE; v_color text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO v_g FROM public.fanorona_games WHERE id=_game_id FOR UPDATE;
  IF v_g.id IS NULL OR v_g.status <> 'drawing' THEN RETURN; END IF;
  IF v_g.draw_white_by IS NULL OR v_g.draw_black_by IS NULL THEN RAISE EXCEPTION 'colors not chosen yet'; END IF;
  IF v_g.draw_result_color IS NOT NULL THEN RETURN; END IF;
  v_color := CASE WHEN (get_byte(gen_random_bytes(1),0) % 2) = 0 THEN 'w' ELSE 'b' END;
  UPDATE public.fanorona_games
     SET draw_result_color = v_color,
         draw_revealed_at = now(),
         draw_spun_by = v_uid
   WHERE id=_game_id AND draw_result_color IS NULL;
END; $function$
;

CREATE OR REPLACE FUNCTION public.fanorona_forfeit(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  g record;
  my_slot int;
BEGIN
  SELECT * INTO g FROM public.fanorona_games WHERE id = _game_id FOR UPDATE;
  IF g.status NOT IN ('open','playing') THEN RETURN; END IF;
  SELECT slot INTO my_slot FROM public.fanorona_participants WHERE game_id = _game_id AND user_id = v_uid;
  IF my_slot IS NULL THEN RETURN; END IF;
  UPDATE public.fanorona_participants SET forfeited = true WHERE game_id = _game_id AND user_id = v_uid;

  IF g.status = 'open' THEN
    UPDATE public.profiles p SET balance_ar = balance_ar + g.stake
      FROM public.fanorona_participants pp WHERE pp.game_id = _game_id AND pp.user_id = p.id;
    INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
      SELECT user_id, 'fanorona_refund', g.stake, _game_id, 'Game cancelled' FROM public.fanorona_participants WHERE game_id = _game_id;
    UPDATE public.fanorona_games SET status = 'cancelled', finished_at = now() WHERE id = _game_id;
    RETURN;
  END IF;

  PERFORM public._fanorona_finalize(_game_id, 1 - my_slot);
END $function$
;

CREATE OR REPLACE FUNCTION public.fanorona_join(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  g record;
  v_balance numeric;
  v_name text;
  v_slot int;
  v_color text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO g FROM public.fanorona_games WHERE id = _game_id FOR UPDATE;
  IF g.id IS NULL OR g.status <> 'open' THEN RAISE EXCEPTION 'game not joinable'; END IF;
  IF EXISTS(SELECT 1 FROM public.fanorona_participants WHERE game_id = _game_id AND user_id = v_uid) THEN RETURN; END IF;
  SELECT balance_ar, pseudo INTO v_balance, v_name FROM public.profiles WHERE id = v_uid;
  IF v_balance < g.stake THEN RAISE EXCEPTION 'insufficient balance'; END IF;
  IF (SELECT count(*) FROM public.fanorona_participants WHERE game_id = _game_id) >= 2 THEN RAISE EXCEPTION 'full'; END IF;

  -- Pick first free slot (0 or 1)
  SELECT s INTO v_slot
  FROM generate_series(0,1) AS s
  WHERE NOT EXISTS (
    SELECT 1 FROM public.fanorona_participants WHERE game_id = _game_id AND slot = s
  )
  ORDER BY s
  LIMIT 1;
  IF v_slot IS NULL THEN RAISE EXCEPTION 'full'; END IF;
  v_color := CASE WHEN v_slot = 0 THEN 'white' ELSE 'black' END;

  INSERT INTO public.fanorona_participants(game_id, user_id, slot, color, display_name)
    VALUES (_game_id, v_uid, v_slot, v_color, COALESCE(v_name,'Player'));
  UPDATE public.profiles SET balance_ar = balance_ar - g.stake WHERE id = v_uid;
  INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
    VALUES (v_uid, 'fanorona_stake', -g.stake, _game_id, 'Join fanorona');
  UPDATE public.fanorona_games SET pot = pot + g.stake WHERE id = _game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.fanorona_join_code(_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g_id uuid;
BEGIN
  SELECT id INTO g_id FROM public.fanorona_games WHERE room_code = upper(_code) AND status = 'open';
  IF g_id IS NULL THEN RAISE EXCEPTION 'invalid code'; END IF;
  PERFORM public.fanorona_join(g_id);
  RETURN g_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.fanorona_play(_game_id uuid, _move jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  g record;
  my_slot int; my_color int; opp_color int;
  st jsonb; board jsonb;
  from_idx int; to_idx int;
  fr int; fc int; tr int; tc int; dr int; dc int;
  is_strong boolean;
  cap jsonb; lists jsonb;
  opp_left int; next_turn int;
  is_pass boolean;
  move_count int;
  visited jsonb;
  last_axis text; axis text;
  chain_from_v int;
  i int;
  v_cols int; v_rows int;
  no_cap int;
  used_approach boolean;
BEGIN
  SELECT * INTO g FROM public.fanorona_games WHERE id = _game_id FOR UPDATE;
  IF g.status <> 'playing' THEN RAISE EXCEPTION 'game not active'; END IF;
  SELECT slot INTO my_slot FROM public.fanorona_participants
    WHERE game_id = _game_id AND user_id = v_uid;
  IF my_slot IS NULL OR my_slot <> g.current_turn THEN RAISE EXCEPTION 'not your turn'; END IF;

  v_cols := COALESCE(g.cols, 9); v_rows := COALESCE(g.rows, 5);
  my_color := CASE WHEN my_slot = 0 THEN 1 ELSE 2 END;
  opp_color := CASE WHEN my_slot = 0 THEN 2 ELSE 1 END;
  st := g.state; board := st -> 'board';
  move_count := COALESCE((st->>'move_count')::int, 0);
  visited := COALESCE(st->'visited', '[]'::jsonb);
  last_axis := NULLIF(st->>'last_axis', '');
  chain_from_v := CASE WHEN st->'chain_from' IS NULL OR st->'chain_from' = 'null'::jsonb
                       THEN NULL ELSE (st->>'chain_from')::int END;
  no_cap := COALESCE((st->>'no_capture_moves')::int, 0);
  is_pass := COALESCE((_move->>'pass')::boolean, false);

  IF is_pass THEN
    next_turn := 1 - my_slot;
    st := jsonb_set(st, '{chain_from}', 'null'::jsonb);
    st := jsonb_set(st, '{visited}', '[]'::jsonb);
    st := jsonb_set(st, '{last_axis}', 'null'::jsonb);
    st := jsonb_set(st, '{move_count}', to_jsonb(move_count + 1));
    st := jsonb_set(st, '{no_capture_moves}', to_jsonb(no_cap + 1), true);
    UPDATE public.fanorona_games SET state = st, current_turn = next_turn,
      turn_deadline = now() + (COALESCE((SELECT turn_timer_seconds FROM public._game_cfg('fanorona')),60) || ' seconds')::interval
      WHERE id = _game_id;
    IF NOT public._fanorona_player_has_move(board, opp_color, v_cols, v_rows) THEN
      PERFORM public._fanorona_finalize(_game_id, my_slot); RETURN;
    END IF;
    IF (no_cap + 1) >= 20
       AND NOT public._fanorona_player_can_capture(board, my_color, v_cols, v_rows)
       AND NOT public._fanorona_player_can_capture(board, opp_color, v_cols, v_rows) THEN
      PERFORM public._fanorona_draw_refund(_game_id); RETURN;
    END IF;
    PERFORM public.fanorona_bot_play(_game_id);
    RETURN;
  END IF;

  from_idx := (_move->>'from')::int;
  to_idx   := (_move->>'to')::int;
  cap      := COALESCE(_move->'captured', '[]'::jsonb);

  IF chain_from_v IS NOT NULL AND from_idx <> chain_from_v THEN
    RAISE EXCEPTION 'must continue with same piece';
  END IF;
  IF (board->from_idx)::int <> my_color THEN RAISE EXCEPTION 'not your piece'; END IF;
  IF (board->to_idx)::int <> 0 THEN RAISE EXCEPTION 'target not empty'; END IF;

  fr := from_idx / v_cols; fc := from_idx % v_cols;
  tr := to_idx   / v_cols; tc := to_idx   % v_cols;
  dr := tr - fr;           dc := tc - fc;
  IF abs(dr) > 1 OR abs(dc) > 1 OR (dr = 0 AND dc = 0) THEN
    RAISE EXCEPTION 'invalid step';
  END IF;
  is_strong := ((fr + fc) % 2 = 0);
  IF NOT is_strong AND (dr <> 0 AND dc <> 0) THEN
    RAISE EXCEPTION 'diagonal not allowed here';
  END IF;
  axis := public._fanorona_axis(dr, dc);

  IF chain_from_v IS NOT NULL THEN
    IF visited @> to_jsonb(to_idx) THEN RAISE EXCEPTION 'cannot revisit cell'; END IF;
    IF last_axis IS NOT NULL AND axis = last_axis THEN
      RAISE EXCEPTION 'cannot continue on same axis';
    END IF;
  END IF;

  lists := public._fanorona_capture_lists(board, my_color, from_idx, to_idx, v_cols, v_rows);
  used_approach := false;
  IF jsonb_array_length(cap) > 0 THEN
    IF cap = (lists->'approach') THEN used_approach := true;
    ELSIF cap = (lists->'withdrawal') THEN used_approach := false;
    ELSE RAISE EXCEPTION 'invalid capture set';
    END IF;
  END IF;

  IF move_count = 0 AND jsonb_array_length(cap) > 0 AND NOT used_approach THEN
    RAISE EXCEPTION 'first move: only approach captures allowed';
  END IF;

  IF jsonb_array_length(cap) = 0 THEN
    IF chain_from_v IS NOT NULL THEN RAISE EXCEPTION 'must capture during chain'; END IF;
    IF COALESCE(g.mandatory_capture, true)
       AND public._fanorona_player_can_capture(board, my_color, v_cols, v_rows) THEN
      RAISE EXCEPTION 'capture is mandatory when available';
    END IF;
  END IF;

  board := jsonb_set(board, ARRAY[from_idx::text], '0'::jsonb);
  board := jsonb_set(board, ARRAY[to_idx::text],   to_jsonb(my_color));
  IF jsonb_array_length(cap) > 0 THEN
    FOR i IN 0..jsonb_array_length(cap) - 1 LOOP
      board := jsonb_set(board, ARRAY[((cap->i)::int)::text], '0'::jsonb);
    END LOOP;
  END IF;
  st := jsonb_set(st, '{board}', board);

  IF jsonb_array_length(cap) > 0 THEN no_cap := 0; ELSE no_cap := no_cap + 1; END IF;
  st := jsonb_set(st, '{no_capture_moves}', to_jsonb(no_cap), true);

  SELECT count(*) INTO opp_left FROM jsonb_array_elements(board) v WHERE (v::text)::int = opp_color;
  IF opp_left = 0 THEN
    UPDATE public.fanorona_games SET state = st WHERE id = _game_id;
    PERFORM public._fanorona_finalize(_game_id, my_slot); RETURN;
  END IF;

  IF jsonb_array_length(cap) = 0 THEN
    next_turn := 1 - my_slot;
    st := jsonb_set(st, '{chain_from}', 'null'::jsonb);
    st := jsonb_set(st, '{visited}', '[]'::jsonb);
    st := jsonb_set(st, '{last_axis}', 'null'::jsonb);
    st := jsonb_set(st, '{move_count}', to_jsonb(move_count + 1));
  ELSE
    IF move_count = 0 THEN
      next_turn := 1 - my_slot;
      st := jsonb_set(st, '{chain_from}', 'null'::jsonb);
      st := jsonb_set(st, '{visited}', '[]'::jsonb);
      st := jsonb_set(st, '{last_axis}', 'null'::jsonb);
      st := jsonb_set(st, '{move_count}', to_jsonb(move_count + 1));
    ELSE
      visited := visited || to_jsonb(from_idx) || to_jsonb(to_idx);
      IF public._fanorona_piece_can_capture(board, my_color, to_idx, visited, axis, v_cols, v_rows) THEN
        next_turn := my_slot;
        st := jsonb_set(st, '{chain_from}', to_jsonb(to_idx));
        st := jsonb_set(st, '{visited}', visited);
        st := jsonb_set(st, '{last_axis}', to_jsonb(axis));
      ELSE
        next_turn := 1 - my_slot;
        st := jsonb_set(st, '{chain_from}', 'null'::jsonb);
        st := jsonb_set(st, '{visited}', '[]'::jsonb);
        st := jsonb_set(st, '{last_axis}', 'null'::jsonb);
        st := jsonb_set(st, '{move_count}', to_jsonb(move_count + 1));
      END IF;
    END IF;
  END IF;

  UPDATE public.fanorona_games SET state = st, current_turn = next_turn,
    turn_deadline = now() + (COALESCE((SELECT turn_timer_seconds FROM public._game_cfg('fanorona')),60) || ' seconds')::interval
    WHERE id = _game_id;

  IF next_turn = 1 - my_slot
     AND NOT public._fanorona_player_has_move(board, opp_color, v_cols, v_rows) THEN
    PERFORM public._fanorona_finalize(_game_id, my_slot); RETURN;
  END IF;

  IF no_cap >= 20
     AND NOT public._fanorona_player_can_capture(board, my_color, v_cols, v_rows)
     AND NOT public._fanorona_player_can_capture(board, opp_color, v_cols, v_rows) THEN
    PERFORM public._fanorona_draw_refund(_game_id); RETURN;
  END IF;

  PERFORM public.fanorona_bot_play(_game_id);
END $function$
;

CREATE OR REPLACE FUNCTION public.fanorona_play_as_bot(_game_id uuid, _move jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  g record; bot_uid uuid;
  my_slot int; my_color int; opp_color int;
  st jsonb; board jsonb;
  from_idx int; to_idx int;
  fr int; fc int; tr int; tc int; dr int; dc int;
  cap jsonb;
  opp_left int; next_turn int;
  is_pass boolean;
  move_count int;
  visited jsonb; last_axis text; axis text;
  chain_from_v int;
  i int;
  v_cols int; v_rows int;
  no_cap int;
BEGIN
  SELECT * INTO g FROM public.fanorona_games WHERE id = _game_id FOR UPDATE;
  IF g.status <> 'playing' THEN RETURN; END IF;
  my_slot := g.current_turn;
  SELECT user_id INTO bot_uid FROM public.fanorona_participants
    WHERE game_id = _game_id AND slot = my_slot AND is_bot = true;
  IF bot_uid IS NULL THEN RETURN; END IF;

  v_cols := COALESCE(g.cols, 9); v_rows := COALESCE(g.rows, 5);
  my_color  := CASE WHEN my_slot = 0 THEN 1 ELSE 2 END;
  opp_color := CASE WHEN my_slot = 0 THEN 2 ELSE 1 END;
  st := g.state; board := st -> 'board';
  move_count := COALESCE((st->>'move_count')::int, 0);
  visited := COALESCE(st->'visited', '[]'::jsonb);
  last_axis := NULLIF(st->>'last_axis', '');
  chain_from_v := CASE WHEN st->'chain_from' IS NULL OR st->'chain_from' = 'null'::jsonb
                       THEN NULL ELSE (st->>'chain_from')::int END;
  no_cap := COALESCE((st->>'no_capture_moves')::int, 0);

  is_pass := COALESCE((_move->>'pass')::boolean, false);
  IF is_pass THEN
    next_turn := 1 - my_slot;
    st := jsonb_set(st, '{chain_from}', 'null'::jsonb);
    st := jsonb_set(st, '{visited}', '[]'::jsonb);
    st := jsonb_set(st, '{last_axis}', 'null'::jsonb);
    st := jsonb_set(st, '{move_count}', to_jsonb(move_count + 1));
    st := jsonb_set(st, '{no_capture_moves}', to_jsonb(no_cap + 1), true);
    UPDATE public.fanorona_games SET state = st, current_turn = next_turn,
      turn_deadline = now() + (COALESCE((SELECT turn_timer_seconds FROM public._game_cfg('fanorona')),60) || ' seconds')::interval
      WHERE id = _game_id;
    IF NOT public._fanorona_player_has_move(board, opp_color, v_cols, v_rows) THEN
      PERFORM public._fanorona_finalize(_game_id, my_slot); RETURN;
    END IF;
    IF (no_cap + 1) >= 20
       AND NOT public._fanorona_player_can_capture(board, my_color, v_cols, v_rows)
       AND NOT public._fanorona_player_can_capture(board, opp_color, v_cols, v_rows) THEN
      PERFORM public._fanorona_draw_refund(_game_id);
    END IF;
    RETURN;
  END IF;

  from_idx := (_move->>'from')::int;
  to_idx   := (_move->>'to')::int;
  cap      := COALESCE(_move->'captured', '[]'::jsonb);
  fr := from_idx / v_cols; fc := from_idx % v_cols;
  tr := to_idx   / v_cols; tc := to_idx   % v_cols;
  dr := tr - fr;           dc := tc - fc;
  axis := public._fanorona_axis(dr, dc);

  board := jsonb_set(board, ARRAY[from_idx::text], '0'::jsonb);
  board := jsonb_set(board, ARRAY[to_idx::text],   to_jsonb(my_color));
  IF jsonb_array_length(cap) > 0 THEN
    FOR i IN 0..jsonb_array_length(cap) - 1 LOOP
      board := jsonb_set(board, ARRAY[((cap->i)::int)::text], '0'::jsonb);
    END LOOP;
  END IF;
  st := jsonb_set(st, '{board}', board);

  IF jsonb_array_length(cap) > 0 THEN no_cap := 0; ELSE no_cap := no_cap + 1; END IF;
  st := jsonb_set(st, '{no_capture_moves}', to_jsonb(no_cap), true);

  SELECT count(*) INTO opp_left FROM jsonb_array_elements(board) v WHERE (v::text)::int = opp_color;
  IF opp_left = 0 THEN
    UPDATE public.fanorona_games SET state = st WHERE id = _game_id;
    PERFORM public._fanorona_finalize(_game_id, my_slot); RETURN;
  END IF;

  IF jsonb_array_length(cap) = 0 THEN
    next_turn := 1 - my_slot;
    st := jsonb_set(st, '{chain_from}', 'null'::jsonb);
    st := jsonb_set(st, '{visited}', '[]'::jsonb);
    st := jsonb_set(st, '{last_axis}', 'null'::jsonb);
    st := jsonb_set(st, '{move_count}', to_jsonb(move_count + 1));
  ELSE
    IF move_count = 0 THEN
      next_turn := 1 - my_slot;
      st := jsonb_set(st, '{chain_from}', 'null'::jsonb);
      st := jsonb_set(st, '{visited}', '[]'::jsonb);
      st := jsonb_set(st, '{last_axis}', 'null'::jsonb);
      st := jsonb_set(st, '{move_count}', to_jsonb(move_count + 1));
    ELSE
      visited := visited || to_jsonb(from_idx) || to_jsonb(to_idx);
      IF public._fanorona_piece_can_capture(board, my_color, to_idx, visited, axis, v_cols, v_rows) THEN
        next_turn := my_slot;
        st := jsonb_set(st, '{chain_from}', to_jsonb(to_idx));
        st := jsonb_set(st, '{visited}', visited);
        st := jsonb_set(st, '{last_axis}', to_jsonb(axis));
      ELSE
        next_turn := 1 - my_slot;
        st := jsonb_set(st, '{chain_from}', 'null'::jsonb);
        st := jsonb_set(st, '{visited}', '[]'::jsonb);
        st := jsonb_set(st, '{last_axis}', 'null'::jsonb);
        st := jsonb_set(st, '{move_count}', to_jsonb(move_count + 1));
      END IF;
    END IF;
  END IF;

  UPDATE public.fanorona_games SET state = st, current_turn = next_turn,
    turn_deadline = now() + (COALESCE((SELECT turn_timer_seconds FROM public._game_cfg('fanorona')),60) || ' seconds')::interval
    WHERE id = _game_id;

  IF next_turn = 1 - my_slot
     AND NOT public._fanorona_player_has_move(board, opp_color, v_cols, v_rows) THEN
    PERFORM public._fanorona_finalize(_game_id, my_slot); RETURN;
  END IF;

  IF no_cap >= 20
     AND NOT public._fanorona_player_can_capture(board, my_color, v_cols, v_rows)
     AND NOT public._fanorona_player_can_capture(board, opp_color, v_cols, v_rows) THEN
    PERFORM public._fanorona_draw_refund(_game_id); RETURN;
  END IF;

  IF next_turn = my_slot THEN
    PERFORM public.fanorona_bot_play(_game_id);
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.fanorona_request_or_accept_draw(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_status text; v_offered uuid;
BEGIN
  SELECT status, draw_offered_by INTO v_status, v_offered FROM public.fanorona_games WHERE id=_game_id FOR UPDATE;
  IF v_status <> 'active' THEN RETURN; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.fanorona_participants WHERE game_id=_game_id AND user_id=v_uid) THEN RETURN; END IF;
  IF v_offered IS NULL THEN
    UPDATE public.fanorona_games SET draw_offered_by=v_uid, updated_at=now() WHERE id=_game_id;
  ELSIF v_offered <> v_uid THEN
    UPDATE public.fanorona_games SET status='finished', result='draw', draw_offered_by=NULL, finished_at=now(), updated_at=now() WHERE id=_game_id;
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fanorona_set_ready(_game_id uuid, _ready boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_total int; v_ready int; v_status text;
        v_starter uuid; v_p1 uuid; v_p2 uuid; v_swap boolean;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  UPDATE public.fanorona_participants SET ready = COALESCE(_ready, false)
    WHERE game_id = _game_id AND user_id = v_uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'not a participant'; END IF;
  SELECT status INTO v_status FROM public.fanorona_games WHERE id = _game_id;
  IF v_status <> 'open' THEN RETURN; END IF;
  SELECT count(*), count(*) FILTER (WHERE ready) INTO v_total, v_ready
    FROM public.fanorona_participants WHERE game_id = _game_id;
  IF v_total = 2 AND v_ready = 2 THEN
    SELECT user_id INTO v_p1 FROM public.fanorona_participants WHERE game_id=_game_id ORDER BY joined_at LIMIT 1;
    SELECT user_id INTO v_p2 FROM public.fanorona_participants WHERE game_id=_game_id AND user_id <> v_p1 LIMIT 1;
    v_swap := (get_byte(extensions.gen_random_bytes(1),0) % 2) = 1;
    v_starter := CASE WHEN v_swap THEN v_p2 ELSE v_p1 END;
    UPDATE public.fanorona_participants
       SET slot  = CASE WHEN user_id = v_starter THEN 0 ELSE 1 END,
           color = CASE WHEN user_id = v_starter THEN 'white' ELSE 'black' END
     WHERE game_id = _game_id;

    UPDATE public.fanorona_games
       SET status = 'playing', started_at = now(), current_turn = 0,
           state = jsonb_set(state, '{phase}', '"playing"'::jsonb),
           turn_deadline = now() + (COALESCE((SELECT turn_timer_seconds FROM public._game_cfg('fanorona')),60) || ' seconds')::interval
     WHERE id = _game_id AND status = 'open';
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.fanorona_start_solo_bot(_variant text DEFAULT 'tsivy'::text, _mandatory_capture boolean DEFAULT true, _difficulty text DEFAULT 'medium'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_name text; v_id uuid;
  v_cols int; v_rows int;
  v_intel int;
  v_bot_name text;
BEGIN
  PERFORM public._assert_solo_bot_enabled();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  CASE _variant
    WHEN 'telo'  THEN v_cols := 3; v_rows := 3;
    WHEN 'dimy'  THEN v_cols := 5; v_rows := 5;
    WHEN 'tsivy' THEN v_cols := 9; v_rows := 5;
    ELSE v_cols := 9; v_rows := 5; _variant := 'tsivy';
  END CASE;
  v_intel := CASE lower(COALESCE(_difficulty,'medium'))
                WHEN 'easy' THEN 1 WHEN 'hard' THEN 3 ELSE 2 END;
  v_bot_name := CASE v_intel WHEN 1 THEN 'Bot Facile'
                             WHEN 3 THEN 'Bot Difficile'
                             ELSE 'Bot Moyen' END;

  SELECT pseudo INTO v_name FROM public.profiles WHERE id = v_uid;

  INSERT INTO public.fanorona_games(
    host_id, stake, pot, commission_pct, is_private, room_code, state,
    cols, rows, variant, mandatory_capture,
    status, current_turn, started_at, turn_deadline
  ) VALUES (
    v_uid, 0, 0, 0, false, NULL,
    jsonb_build_object('phase','playing','board', public._fanorona_init_board(v_cols, v_rows),
                       'chain_from', null, 'visited', '[]'::jsonb,
                       'last_axis', null, 'move_count', 0),
    v_cols, v_rows, _variant, COALESCE(_mandatory_capture, true),
    'playing', 0, now(),
    now() + (COALESCE((SELECT turn_timer_seconds FROM public._game_cfg('fanorona')),60) || ' seconds')::interval
  ) RETURNING id INTO v_id;

  -- Human = slot 0 (white, plays first per Fanorona conventions here)
  INSERT INTO public.fanorona_participants(game_id, user_id, slot, color, display_name, ready)
    VALUES (v_id, v_uid, 0, 'white', COALESCE(v_name,'Vous'), true);
  -- Bot = slot 1 (black)
  INSERT INTO public.fanorona_participants(
    game_id, user_id, slot, color, display_name, ready, is_bot, bot_intelligence, bot_name
  ) VALUES (
    v_id, NULL, 1, 'black', v_bot_name, true, true, v_intel, v_bot_name
  );

  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.fanorona_tick(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g record; cur_uid uuid; _cfg record; _skips int; _next int; v_is_bot boolean;
BEGIN
  SELECT * INTO g FROM public.fanorona_games WHERE id = _game_id FOR UPDATE;
  IF g IS NULL OR g.status <> 'playing' THEN RETURN; END IF;

  SELECT COALESCE(is_bot,false), user_id INTO v_is_bot, cur_uid
    FROM public.fanorona_participants WHERE game_id = _game_id AND slot = g.current_turn;

  IF v_is_bot THEN
    PERFORM public.fanorona_bot_play(_game_id); RETURN;
  END IF;

  IF g.turn_deadline IS NULL OR g.turn_deadline > now() THEN RETURN; END IF;
  SELECT * INTO _cfg FROM public._game_cfg('fanorona');
  _skips := COALESCE((g.turn_skips->>cur_uid::text)::int, 0) + 1;
  IF _skips >= _cfg.max_turn_skips THEN
    UPDATE public.fanorona_participants SET forfeited = true WHERE game_id = _game_id AND user_id = cur_uid;
    PERFORM public._fanorona_finalize(_game_id, 1 - g.current_turn); RETURN;
  END IF;
  _next := 1 - g.current_turn;
  UPDATE public.fanorona_games SET
    current_turn = _next,
    turn_skips = jsonb_set(g.turn_skips, ARRAY[cur_uid::text], to_jsonb(_skips)),
    turn_deadline = now() + (_cfg.turn_timer_seconds || ' seconds')::interval
  WHERE id = _game_id;
  SELECT COALESCE(is_bot,false) INTO v_is_bot FROM public.fanorona_participants
    WHERE game_id = _game_id AND slot = _next;
  IF v_is_bot THEN PERFORM public.fanorona_bot_play(_game_id); END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.find_or_create_game(_max_players integer, _stake numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid UUID := auth.uid(); v_target UUID;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  PERFORM public.ludo_cleanup_empty_rooms();
  SELECT g.id INTO v_target
    FROM public.ludo_games g
    WHERE g.status='open' AND g.is_private=false AND g.max_players=_max_players AND g.stake=_stake
      AND (SELECT count(*) FROM public.ludo_participants p WHERE p.game_id=g.id) > 0
      AND (SELECT count(*) FROM public.ludo_participants p WHERE p.game_id=g.id) < g.max_players
      AND NOT EXISTS (SELECT 1 FROM public.ludo_participants p WHERE p.game_id=g.id AND p.user_id=v_uid)
    ORDER BY (SELECT count(*) FROM public.ludo_participants p WHERE p.game_id=g.id) DESC, g.created_at ASC
    LIMIT 1;
  IF v_target IS NOT NULL THEN
    PERFORM public.join_game(v_target);
    RETURN v_target;
  END IF;
  RETURN public.create_game(_max_players, _stake);
END $function$
;

CREATE OR REPLACE FUNCTION public.finish_game(_game_id uuid, _winner_id uuid)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_game public.ludo_games%ROWTYPE;
  v_payout NUMERIC;
  v_referrer UUID;
  v_ref_pct NUMERIC;
  v_ref_amount NUMERIC;
  v_caller uuid := auth.uid();
BEGIN
  SELECT * INTO v_game FROM public.ludo_games WHERE id=_game_id FOR UPDATE;
  IF v_game.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  IF v_game.status = 'finished' THEN RETURN 0; END IF;

  -- AUTH GUARD: only an internal SECURITY DEFINER caller (auth.uid() NULL inside DB cron etc),
  -- or a participant / host / admin can trigger.
  IF v_caller IS NOT NULL
     AND v_caller <> v_game.host_id
     AND NOT public._is_game_participant(_game_id, v_caller)
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Non autorisé';
  END IF;

  IF _winner_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.ludo_participants WHERE game_id=_game_id AND user_id=_winner_id AND is_bot=FALSE
  ) THEN
    RAISE EXCEPTION 'Gagnant invalide';
  END IF;

  v_payout := v_game.pot * (100 - v_game.commission_pct) / 100.0;
  UPDATE public.ludo_games SET status='finished', winner_id=_winner_id, finished_at=now() WHERE id=_game_id;

  IF _winner_id IS NOT NULL THEN
    UPDATE public.profiles SET balance_ar = balance_ar + v_payout WHERE id=_winner_id;
    INSERT INTO public.transactions(user_id,type,amount,ref_id,note) VALUES (_winner_id,'win',v_payout,_game_id,'Gain partie');

    SELECT referred_by INTO v_referrer FROM public.profiles WHERE id=_winner_id;
    IF v_referrer IS NOT NULL THEN
      SELECT referral_pct INTO v_ref_pct FROM public.app_settings WHERE id=1;
      v_ref_amount := v_payout * COALESCE(v_ref_pct,0) / 100.0;
      IF v_ref_amount > 0 THEN
        UPDATE public.profiles SET balance_ar = balance_ar + v_ref_amount WHERE id=v_referrer;
        INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
          VALUES (v_referrer,'referral',v_ref_amount,_game_id,'Bonus parrainage');
      END IF;
    END IF;
  END IF;

  RETURN v_payout;
END $function$
;

CREATE OR REPLACE FUNCTION public.friendships_touch_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$function$
;

CREATE OR REPLACE FUNCTION public.game_online_count(_slug text)
 RETURNS bigint
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT CASE _slug
    WHEN 'ludo'     THEN (SELECT count(*) FROM public.ludo_games     WHERE status::text IN ('waiting','playing'))
    WHEN 'domino'   THEN (SELECT count(*) FROM public.domino_games   WHERE status::text IN ('waiting','playing'))
    WHEN 'fanorona' THEN (SELECT count(*) FROM public.fanorona_games WHERE status::text IN ('waiting','playing'))
    WHEN 'chess'    THEN (SELECT count(*) FROM public.chess_games    WHERE status::text IN ('waiting','playing'))
    WHEN 'rami'     THEN (SELECT count(*) FROM public.rami_games     WHERE status::text IN ('waiting','playing'))
    WHEN 'poker'    THEN (SELECT count(*) FROM public.poker_games    WHERE status IN ('waiting','playing'))
    ELSE 0
  END;
$function$
;

CREATE OR REPLACE FUNCTION public.game_player_status(_user_id uuid, _slug text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_playing boolean := false;
  v_pct int := 0;
  v_state jsonb;
  v_slot int;
  v_sum numeric := 0;
  v_count int := 0;
  v_pawn jsonb;
  v_board jsonb;
  v_ply int;
  v_my_color int;
  v_opp_color int;
  v_opp_remaining int := 0;
  i int;
BEGIN
  IF _slug = 'ludo' THEN
    SELECT g.state, lp.slot INTO v_state, v_slot
      FROM ludo_participants lp JOIN ludo_games g ON g.id = lp.game_id
      WHERE lp.user_id = _user_id AND g.status='playing' LIMIT 1;
    IF v_state IS NOT NULL THEN
      v_playing := true;
      FOR v_pawn IN SELECT * FROM jsonb_array_elements(COALESCE(v_state->'pawns'->v_slot::text, '[]'::jsonb))
      LOOP
        v_count := v_count + 1;
        IF v_pawn->>'s' = 'home' THEN v_sum := v_sum + 100;
        ELSIF v_pawn->>'s' = 'track' THEN v_sum := v_sum + LEAST(95, ((v_pawn->>'k')::int * 100.0) / 56);
        END IF;
      END LOOP;
      IF v_count > 0 THEN v_pct := ROUND(v_sum / v_count); END IF;
    END IF;
  ELSIF _slug = 'domino' THEN
    SELECT g.state INTO v_state FROM domino_participants dp JOIN domino_games g ON g.id=dp.game_id
      WHERE dp.user_id=_user_id AND g.status='playing' LIMIT 1;
    IF v_state IS NOT NULL THEN
      v_playing := true;
      v_pct := LEAST(99, (jsonb_array_length(COALESCE(v_state->'board','[]'::jsonb)) * 100) / 28);
    END IF;
  ELSIF _slug = 'fanorona' THEN
    SELECT g.state, fp.slot INTO v_state, v_slot
      FROM fanorona_participants fp JOIN fanorona_games g ON g.id=fp.game_id
      WHERE fp.user_id=_user_id AND g.status='playing' LIMIT 1;
    IF v_state IS NOT NULL THEN
      v_playing := true;
      v_my_color := CASE WHEN v_slot = 0 THEN 1 ELSE 2 END;
      v_opp_color := CASE WHEN v_my_color = 1 THEN 2 ELSE 1 END;
      v_board := COALESCE(v_state->'board', '[]'::jsonb);
      FOR i IN 0..jsonb_array_length(v_board)-1 LOOP
        IF (v_board->i)::int = v_opp_color THEN v_opp_remaining := v_opp_remaining + 1; END IF;
      END LOOP;
      v_pct := LEAST(99, ROUND(((22 - v_opp_remaining)::numeric * 100) / 22));
      IF v_pct < 0 THEN v_pct := 0; END IF;
    END IF;
  ELSIF _slug = 'chess' THEN
    SELECT ply FROM chess_games WHERE status='playing' AND (white_id=_user_id OR black_id=_user_id) LIMIT 1 INTO v_ply;
    IF v_ply IS NOT NULL THEN v_playing := true; v_pct := LEAST(99, (v_ply * 100) / 80); END IF;
  END IF;
  RETURN jsonb_build_object('playing', v_playing, 'percent', v_pct);
END $function$
;

CREATE OR REPLACE FUNCTION public.game_request_afk_pause(_slug text, _game_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid UUID := auth.uid(); v_status TEXT; v_paused BOOLEAN; v_warning JSONB; v_afk_uid UUID;
  v_is_participant BOOLEAN := FALSE; v_remaining_s INT; v_votes JSONB; v_votes_needed INT; v_active_count INT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  CASE _slug
    WHEN 'ludo' THEN
      SELECT status, paused, afk_warning INTO v_status, v_paused, v_warning FROM public.ludo_games WHERE id = _game_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'partie introuvable'; END IF;
      SELECT EXISTS(SELECT 1 FROM public.ludo_participants WHERE game_id = _game_id AND user_id = v_uid AND is_bot = FALSE AND forfeited = FALSE) INTO v_is_participant;
    WHEN 'chess' THEN
      SELECT status, paused, afk_warning, CEIL(GREATEST(0, EXTRACT(EPOCH FROM (turn_deadline - now())))) INTO v_status, v_paused, v_warning, v_remaining_s FROM public.chess_games WHERE id = _game_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'partie introuvable'; END IF;
      SELECT EXISTS(SELECT 1 FROM public.chess_games WHERE id = _game_id AND (white_id = v_uid OR black_id = v_uid)) INTO v_is_participant;
    WHEN 'fanorona' THEN
      SELECT status, paused, afk_warning, CEIL(GREATEST(0, EXTRACT(EPOCH FROM (turn_deadline - now())))) INTO v_status, v_paused, v_warning, v_remaining_s FROM public.fanorona_games WHERE id = _game_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'partie introuvable'; END IF;
      SELECT EXISTS(SELECT 1 FROM public.fanorona_participants WHERE game_id = _game_id AND user_id = v_uid AND forfeited = FALSE) INTO v_is_participant;
    WHEN 'domino' THEN
      SELECT status, paused, afk_warning, CEIL(GREATEST(0, EXTRACT(EPOCH FROM (turn_deadline - now())))) INTO v_status, v_paused, v_warning, v_remaining_s FROM public.domino_games WHERE id = _game_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'partie introuvable'; END IF;
      SELECT EXISTS(SELECT 1 FROM public.domino_participants WHERE game_id = _game_id AND user_id = v_uid AND forfeited = FALSE) INTO v_is_participant;
    WHEN 'rami' THEN
      SELECT status, paused, afk_warning, CEIL(GREATEST(0, EXTRACT(EPOCH FROM (turn_deadline - now())))) INTO v_status, v_paused, v_warning, v_remaining_s FROM public.rami_games WHERE id = _game_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'partie introuvable'; END IF;
      SELECT EXISTS(SELECT 1 FROM public.rami_participants WHERE game_id = _game_id AND user_id = v_uid AND forfeited = FALSE) INTO v_is_participant;
    WHEN 'poker' THEN
      SELECT status, paused, afk_warning, CEIL(GREATEST(0, EXTRACT(EPOCH FROM (turn_deadline - now())))) INTO v_status, v_paused, v_warning, v_remaining_s FROM public.poker_games WHERE id = _game_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'partie introuvable'; END IF;
      SELECT EXISTS(SELECT 1 FROM public.poker_players WHERE game_id = _game_id AND user_id = v_uid) INTO v_is_participant;
    ELSE RAISE EXCEPTION 'slug invalide: %', _slug;
  END CASE;
  IF v_status <> 'playing' THEN RAISE EXCEPTION 'la partie n''est pas en cours'; END IF;
  IF COALESCE(v_paused, FALSE) THEN RAISE EXCEPTION 'la partie est déjà en pause'; END IF;
  IF NOT v_is_participant THEN RAISE EXCEPTION 'vous n''êtes pas participant'; END IF;
  IF v_warning IS NULL THEN RAISE EXCEPTION 'aucun joueur en état AFK critique'; END IF;
  v_afk_uid := (v_warning->>'uid')::uuid;
  IF v_uid = v_afk_uid THEN RAISE EXCEPTION 'vous ne pouvez pas déclencher votre propre pause AFK'; END IF;
  v_votes := COALESCE(v_warning->'votes', '[]'::jsonb);
  IF v_votes @> to_jsonb(ARRAY[v_uid::text]) THEN RETURN jsonb_build_object('status', 'already_voted'); END IF;
  v_votes := v_votes || to_jsonb(ARRAY[v_uid::text]);
  CASE _slug
    WHEN 'ludo' THEN SELECT COUNT(*) INTO v_active_count FROM public.ludo_participants WHERE game_id = _game_id AND is_bot = FALSE AND forfeited = FALSE AND user_id <> v_afk_uid;
    WHEN 'chess' THEN v_active_count := 1;
    WHEN 'fanorona' THEN SELECT COUNT(*) INTO v_active_count FROM public.fanorona_participants WHERE game_id = _game_id AND forfeited = FALSE AND user_id <> v_afk_uid;
    WHEN 'domino' THEN SELECT COUNT(*) INTO v_active_count FROM public.domino_participants WHERE game_id = _game_id AND forfeited = FALSE AND user_id <> v_afk_uid;
    WHEN 'rami' THEN SELECT COUNT(*) INTO v_active_count FROM public.rami_participants WHERE game_id = _game_id AND forfeited = FALSE AND user_id <> v_afk_uid;
    WHEN 'poker' THEN SELECT COUNT(*) INTO v_active_count FROM public.poker_players WHERE game_id = _game_id AND user_id <> v_afk_uid;
  END CASE;
  v_votes_needed := GREATEST(1, CEIL(v_active_count::numeric / 2));
  IF jsonb_array_length(v_votes) < v_votes_needed THEN
    CASE _slug
      WHEN 'ludo'     THEN UPDATE public.ludo_games     SET afk_warning = jsonb_set(jsonb_set(afk_warning, '{votes}', v_votes), '{votes_needed}', to_jsonb(v_votes_needed)) WHERE id = _game_id;
      WHEN 'chess'    THEN UPDATE public.chess_games    SET afk_warning = jsonb_set(jsonb_set(afk_warning, '{votes}', v_votes), '{votes_needed}', to_jsonb(v_votes_needed)) WHERE id = _game_id;
      WHEN 'fanorona' THEN UPDATE public.fanorona_games SET afk_warning = jsonb_set(jsonb_set(afk_warning, '{votes}', v_votes), '{votes_needed}', to_jsonb(v_votes_needed)) WHERE id = _game_id;
      WHEN 'domino'   THEN UPDATE public.domino_games   SET afk_warning = jsonb_set(jsonb_set(afk_warning, '{votes}', v_votes), '{votes_needed}', to_jsonb(v_votes_needed)) WHERE id = _game_id;
      WHEN 'rami'     THEN UPDATE public.rami_games     SET afk_warning = jsonb_set(jsonb_set(afk_warning, '{votes}', v_votes), '{votes_needed}', to_jsonb(v_votes_needed)) WHERE id = _game_id;
      WHEN 'poker'    THEN UPDATE public.poker_games    SET afk_warning = jsonb_set(jsonb_set(afk_warning, '{votes}', v_votes), '{votes_needed}', to_jsonb(v_votes_needed)) WHERE id = _game_id;
    END CASE;
    RETURN jsonb_build_object('status', 'vote_registered', 'votes', jsonb_array_length(v_votes), 'votes_needed', v_votes_needed);
  END IF;
  CASE _slug
    WHEN 'ludo' THEN UPDATE public.ludo_games SET paused = TRUE, pause_deadline = now() + interval '3 minutes', afk_pause_for = v_afk_uid, afk_pause_name = v_warning->>'name', afk_warning = NULL, state = jsonb_set(state, '{turn_started_at}', to_jsonb((now() + interval '1 hour')::text), true) WHERE id = _game_id;
    WHEN 'chess' THEN UPDATE public.chess_games SET paused = TRUE, pause_deadline = now() + interval '3 minutes', paused_turn_remaining_s = COALESCE(v_remaining_s, 30), turn_deadline = NULL, afk_pause_for = v_afk_uid, afk_pause_name = v_warning->>'name', afk_warning = NULL WHERE id = _game_id;
    WHEN 'fanorona' THEN UPDATE public.fanorona_games SET paused = TRUE, pause_deadline = now() + interval '3 minutes', paused_turn_remaining_s = COALESCE(v_remaining_s, 60), turn_deadline = NULL, afk_pause_for = v_afk_uid, afk_pause_name = v_warning->>'name', afk_warning = NULL WHERE id = _game_id;
    WHEN 'domino' THEN UPDATE public.domino_games SET paused = TRUE, pause_deadline = now() + interval '3 minutes', paused_turn_remaining_s = COALESCE(v_remaining_s, 60), turn_deadline = NULL, afk_pause_for = v_afk_uid, afk_pause_name = v_warning->>'name', afk_warning = NULL WHERE id = _game_id;
    WHEN 'rami' THEN UPDATE public.rami_games SET paused = TRUE, pause_deadline = now() + interval '3 minutes', paused_turn_remaining_s = COALESCE(v_remaining_s, 45), turn_deadline = NULL, afk_pause_for = v_afk_uid, afk_pause_name = v_warning->>'name', afk_warning = NULL WHERE id = _game_id;
    WHEN 'poker' THEN UPDATE public.poker_games SET paused = TRUE, pause_deadline = now() + interval '3 minutes', paused_turn_remaining_s = COALESCE(v_remaining_s, 30), turn_deadline = NULL, afk_pause_for = v_afk_uid, afk_pause_name = v_warning->>'name', afk_warning = NULL WHERE id = _game_id;
  END CASE;
  RETURN jsonb_build_object('status', 'paused', 'votes', jsonb_array_length(v_votes), 'votes_needed', v_votes_needed);
END $function$
;

CREATE OR REPLACE FUNCTION public.game_request_pause(_slug text, _game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid              UUID    := auth.uid();
  v_status           TEXT;
  v_paused           BOOLEAN;
  v_turn_deadline    TIMESTAMPTZ;
  v_turn_timer       INT;
  v_remaining        FLOAT;
  v_is_participant   BOOLEAN := FALSE;
  v_pause_used       BOOLEAN := FALSE;
  v_turn_uid         UUID;
  v_turn_skips       JSONB;
  v_skips            INT;
  v_has_bot          BOOLEAN := FALSE;
  v_turn_color       TEXT;
  v_white_id         UUID;
  v_black_id         UUID;
  v_current_turn     INT;
  v_turn_started_at  TIMESTAMPTZ;
  v_afk_t1           INT;
  v_afk_t2           INT;
  v_afk_t1_max       INT;
  v_afk_t2_max       INT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;

  CASE _slug
    WHEN 'chess' THEN
      SELECT status, paused, turn_deadline, turn, white_id, black_id, pause_used, turn_skips
        INTO v_status, v_paused, v_turn_deadline, v_turn_color, v_white_id, v_black_id, v_pause_used, v_turn_skips
        FROM public.chess_games WHERE id = _game_id;
      v_turn_uid := CASE WHEN v_turn_color = 'w' THEN v_white_id ELSE v_black_id END;
      v_is_participant := (v_uid = v_white_id OR v_uid = v_black_id);

    WHEN 'fanorona' THEN
      SELECT status, paused, turn_deadline, current_turn, pause_used, turn_skips
        INTO v_status, v_paused, v_turn_deadline, v_current_turn, v_pause_used, v_turn_skips
        FROM public.fanorona_games WHERE id = _game_id;
      SELECT user_id INTO v_turn_uid FROM public.fanorona_participants
        WHERE game_id = _game_id AND slot = v_current_turn;
      SELECT EXISTS(SELECT 1 FROM public.fanorona_participants
        WHERE game_id = _game_id AND user_id = v_uid) INTO v_is_participant;
      SELECT EXISTS(SELECT 1 FROM public.fanorona_participants
        WHERE game_id = _game_id AND is_bot = TRUE) INTO v_has_bot;

    WHEN 'domino' THEN
      SELECT status, paused, turn_deadline, current_turn, pause_used, turn_skips
        INTO v_status, v_paused, v_turn_deadline, v_current_turn, v_pause_used, v_turn_skips
        FROM public.domino_games WHERE id = _game_id;
      SELECT user_id INTO v_turn_uid FROM public.domino_participants
        WHERE game_id = _game_id AND slot = v_current_turn;
      SELECT EXISTS(SELECT 1 FROM public.domino_participants
        WHERE game_id = _game_id AND user_id = v_uid) INTO v_is_participant;
      SELECT EXISTS(SELECT 1 FROM public.domino_participants
        WHERE game_id = _game_id AND is_bot = TRUE) INTO v_has_bot;

    WHEN 'rami' THEN
      SELECT status, paused, turn_deadline, current_turn, pause_used, turn_skips
        INTO v_status, v_paused, v_turn_deadline, v_current_turn, v_pause_used, v_turn_skips
        FROM public.rami_games WHERE id = _game_id;
      SELECT user_id INTO v_turn_uid FROM public.rami_participants
        WHERE game_id = _game_id AND slot = v_current_turn;
      SELECT EXISTS(SELECT 1 FROM public.rami_participants
        WHERE game_id = _game_id AND user_id = v_uid) INTO v_is_participant;

    WHEN 'poker' THEN
      SELECT status, paused, turn_deadline, current_player, pause_used
        INTO v_status, v_paused, v_turn_deadline, v_turn_uid, v_pause_used
        FROM public.poker_games WHERE id = _game_id;
      SELECT EXISTS(SELECT 1 FROM public.poker_players
        WHERE game_id = _game_id AND user_id = v_uid) INTO v_is_participant;

    WHEN 'ludo' THEN
      SELECT status, paused, (state->>'turn_started_at')::timestamptz, current_turn, pause_used
        INTO v_status, v_paused, v_turn_started_at, v_current_turn, v_pause_used
        FROM public.ludo_games WHERE id = _game_id;
      v_turn_deadline := NULL;
      SELECT user_id INTO v_turn_uid FROM public.ludo_participants
        WHERE game_id = _game_id AND slot = v_current_turn;
      SELECT afk_t1, afk_t2 INTO v_afk_t1, v_afk_t2 FROM public.ludo_participants
        WHERE game_id = _game_id AND slot = v_current_turn;
      SELECT afk_t1_max, afk_t2_max INTO v_afk_t1_max, v_afk_t2_max
        FROM public.app_settings WHERE id = 1;
      SELECT EXISTS(SELECT 1 FROM public.ludo_participants
        WHERE game_id = _game_id AND user_id = v_uid AND is_bot = FALSE) INTO v_is_participant;
      SELECT EXISTS(SELECT 1 FROM public.ludo_participants
        WHERE game_id = _game_id AND is_bot = TRUE) INTO v_has_bot;

    ELSE RAISE EXCEPTION 'slug invalide: %', _slug;
  END CASE;

  IF NOT FOUND            THEN RAISE EXCEPTION 'partie introuvable'; END IF;
  IF v_status <> 'playing' THEN RAISE EXCEPTION 'la partie n''est pas en cours'; END IF;
  IF v_paused              THEN RAISE EXCEPTION 'la partie est déjà en pause'; END IF;
  IF NOT v_is_participant  THEN RAISE EXCEPTION 'vous n''êtes pas participant'; END IF;

  -- vs-bot: pause libre, sans échéance, sans limite d'usage.
  IF v_has_bot THEN
    CASE _slug
      WHEN 'fanorona' THEN
        UPDATE public.fanorona_games
          SET paused=TRUE, pause_deadline=NULL,
              paused_turn_remaining_s=CEIL(GREATEST(0,EXTRACT(EPOCH FROM (v_turn_deadline-now())))),
              turn_deadline=NULL
          WHERE id=_game_id AND status='playing' AND paused=FALSE;
      WHEN 'domino' THEN
        UPDATE public.domino_games
          SET paused=TRUE, pause_deadline=NULL,
              paused_turn_remaining_s=CEIL(GREATEST(0,EXTRACT(EPOCH FROM (v_turn_deadline-now())))),
              turn_deadline=NULL
          WHERE id=_game_id AND status='playing' AND paused=FALSE;
      WHEN 'ludo' THEN
        UPDATE public.ludo_games
          SET paused=TRUE, pause_deadline=NULL,
              state=jsonb_set(state,'{turn_started_at}',
                to_jsonb((now()+interval '100 years')::text), true)
          WHERE id=_game_id AND status='playing' AND paused=FALSE;
      ELSE NULL;
    END CASE;
    RETURN;
  END IF;

  IF v_pause_used          THEN RAISE EXCEPTION 'la pause a déjà été utilisée pour cette partie'; END IF;

  IF v_turn_uid IS NOT NULL AND v_uid = v_turn_uid THEN
    RAISE EXCEPTION 'seul un joueur qui attend son tour peut demander la pause';
  END IF;

  IF _slug = 'ludo' THEN
    IF v_turn_started_at IS NULL THEN RAISE EXCEPTION 'pas de tour actif'; END IF;
    v_afk_t1_max := COALESCE(v_afk_t1_max, 2);
    v_afk_t2_max := COALESCE(v_afk_t2_max, 2);
    IF COALESCE(v_afk_t1,0) < v_afk_t1_max AND COALESCE(v_afk_t2,0) < v_afk_t2_max THEN
      RAISE EXCEPTION 'pause disponible seulement après % tours manqués consécutifs',
        LEAST(v_afk_t1_max, v_afk_t2_max);
    END IF;
  ELSIF _slug = 'poker' THEN
    IF v_turn_deadline IS NULL THEN RAISE EXCEPTION 'pas de tour actif'; END IF;
    v_turn_timer := COALESCE((SELECT turn_timer_seconds FROM public._game_cfg(_slug)), 30);
    v_remaining  := GREATEST(0, EXTRACT(EPOCH FROM (v_turn_deadline - now())));
    IF v_remaining > (v_turn_timer * 2.0 / 5.0) THEN
      RAISE EXCEPTION 'pause disponible seulement après 3/5 du temps de tour';
    END IF;
  ELSE
    IF v_turn_deadline IS NULL THEN RAISE EXCEPTION 'pas de tour actif'; END IF;
    v_skips := COALESCE((v_turn_skips->>v_turn_uid::text)::int, 0);
    IF v_skips < 2 THEN
      RAISE EXCEPTION 'pause disponible seulement après 2 tours manqués consécutifs';
    END IF;
  END IF;

  CASE _slug
    WHEN 'chess' THEN
      UPDATE public.chess_games
         SET paused=TRUE, pause_deadline=now()+interval '3 minutes',
             paused_turn_remaining_s=CEIL(GREATEST(0,EXTRACT(EPOCH FROM (v_turn_deadline-now())))),
             turn_deadline=NULL, pause_used=TRUE
       WHERE id=_game_id AND status='playing' AND paused=FALSE;
    WHEN 'fanorona' THEN
      UPDATE public.fanorona_games
         SET paused=TRUE, pause_deadline=now()+interval '3 minutes',
             paused_turn_remaining_s=CEIL(GREATEST(0,EXTRACT(EPOCH FROM (v_turn_deadline-now())))),
             turn_deadline=NULL, pause_used=TRUE
       WHERE id=_game_id AND status='playing' AND paused=FALSE;
    WHEN 'domino' THEN
      UPDATE public.domino_games
         SET paused=TRUE, pause_deadline=now()+interval '3 minutes',
             paused_turn_remaining_s=CEIL(GREATEST(0,EXTRACT(EPOCH FROM (v_turn_deadline-now())))),
             turn_deadline=NULL, pause_used=TRUE
       WHERE id=_game_id AND status='playing' AND paused=FALSE;
    WHEN 'rami' THEN
      UPDATE public.rami_games
         SET paused=TRUE, pause_deadline=now()+interval '3 minutes',
             paused_turn_remaining_s=CEIL(GREATEST(0,EXTRACT(EPOCH FROM (v_turn_deadline-now())))),
             turn_deadline=NULL, pause_used=TRUE
       WHERE id=_game_id AND status='playing' AND paused=FALSE;
    WHEN 'poker' THEN
      UPDATE public.poker_games
         SET paused=TRUE, pause_deadline=now()+interval '3 minutes',
             paused_turn_remaining_s=CEIL(GREATEST(0,EXTRACT(EPOCH FROM (v_turn_deadline-now())))),
             turn_deadline=NULL, pause_used=TRUE
       WHERE id=_game_id AND status='playing' AND paused=FALSE;
    WHEN 'ludo' THEN
      UPDATE public.ludo_games
         SET paused=TRUE, pause_deadline=now()+interval '3 minutes',
             pause_used=TRUE,
             state=jsonb_set(state,'{turn_started_at}',
               to_jsonb((now()+interval '1 hour')::text), true)
       WHERE id=_game_id AND status='playing' AND paused=FALSE;
  END CASE;
END $function$
;

CREATE OR REPLACE FUNCTION public.game_resume(_slug text, _game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid UUID := auth.uid(); v_status TEXT; v_paused BOOLEAN; v_remaining_s INTEGER; v_is_participant BOOLEAN := FALSE;
BEGIN
  CASE _slug
    WHEN 'chess' THEN
      SELECT status, paused, paused_turn_remaining_s INTO v_status, v_paused, v_remaining_s FROM public.chess_games WHERE id = _game_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'partie introuvable'; END IF;
      IF v_uid IS NOT NULL THEN SELECT EXISTS(SELECT 1 FROM public.chess_games WHERE id = _game_id AND (white_id = v_uid OR black_id = v_uid)) INTO v_is_participant; ELSE v_is_participant := TRUE; END IF;
    WHEN 'fanorona' THEN
      SELECT status, paused, paused_turn_remaining_s INTO v_status, v_paused, v_remaining_s FROM public.fanorona_games WHERE id = _game_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'partie introuvable'; END IF;
      IF v_uid IS NOT NULL THEN SELECT EXISTS(SELECT 1 FROM public.fanorona_participants WHERE game_id = _game_id AND user_id = v_uid) INTO v_is_participant; ELSE v_is_participant := TRUE; END IF;
    WHEN 'domino' THEN
      SELECT status, paused, paused_turn_remaining_s INTO v_status, v_paused, v_remaining_s FROM public.domino_games WHERE id = _game_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'partie introuvable'; END IF;
      IF v_uid IS NOT NULL THEN SELECT EXISTS(SELECT 1 FROM public.domino_participants WHERE game_id = _game_id AND user_id = v_uid) INTO v_is_participant; ELSE v_is_participant := TRUE; END IF;
    WHEN 'rami' THEN
      SELECT status, paused, paused_turn_remaining_s INTO v_status, v_paused, v_remaining_s FROM public.rami_games WHERE id = _game_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'partie introuvable'; END IF;
      IF v_uid IS NOT NULL THEN SELECT EXISTS(SELECT 1 FROM public.rami_participants WHERE game_id = _game_id AND user_id = v_uid) INTO v_is_participant; ELSE v_is_participant := TRUE; END IF;
    WHEN 'poker' THEN
      SELECT status, paused, paused_turn_remaining_s INTO v_status, v_paused, v_remaining_s FROM public.poker_games WHERE id = _game_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'partie introuvable'; END IF;
      IF v_uid IS NOT NULL THEN SELECT EXISTS(SELECT 1 FROM public.poker_players WHERE game_id = _game_id AND user_id = v_uid) INTO v_is_participant; ELSE v_is_participant := TRUE; END IF;
    WHEN 'ludo' THEN
      SELECT status, paused INTO v_status, v_paused FROM public.ludo_games WHERE id = _game_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'partie introuvable'; END IF;
      IF v_uid IS NOT NULL THEN SELECT EXISTS(SELECT 1 FROM public.ludo_participants WHERE game_id = _game_id AND user_id = v_uid AND is_bot = FALSE) INTO v_is_participant; ELSE v_is_participant := TRUE; END IF;
    ELSE RAISE EXCEPTION 'slug invalide: %', _slug;
  END CASE;
  IF v_status <> 'playing' THEN RETURN; END IF;
  IF NOT v_paused THEN RETURN; END IF;
  IF NOT v_is_participant THEN RAISE EXCEPTION 'vous n''êtes pas participant'; END IF;
  CASE _slug
    WHEN 'chess' THEN UPDATE public.chess_games SET paused = FALSE, pause_deadline = NULL, paused_turn_remaining_s = NULL, afk_pause_for = NULL, afk_pause_name = NULL, afk_warning = NULL, turn_deadline = now() + (COALESCE(v_remaining_s, 30) || ' seconds')::interval WHERE id = _game_id;
    WHEN 'fanorona' THEN UPDATE public.fanorona_games SET paused = FALSE, pause_deadline = NULL, paused_turn_remaining_s = NULL, afk_pause_for = NULL, afk_pause_name = NULL, afk_warning = NULL, turn_deadline = now() + (COALESCE(v_remaining_s, 60) || ' seconds')::interval WHERE id = _game_id;
    WHEN 'domino' THEN UPDATE public.domino_games SET paused = FALSE, pause_deadline = NULL, paused_turn_remaining_s = NULL, afk_pause_for = NULL, afk_pause_name = NULL, afk_warning = NULL, turn_deadline = now() + (COALESCE(v_remaining_s, 60) || ' seconds')::interval WHERE id = _game_id;
    WHEN 'rami' THEN UPDATE public.rami_games SET paused = FALSE, pause_deadline = NULL, paused_turn_remaining_s = NULL, afk_pause_for = NULL, afk_pause_name = NULL, afk_warning = NULL, turn_deadline = now() + (COALESCE(v_remaining_s, 45) || ' seconds')::interval WHERE id = _game_id;
    WHEN 'poker' THEN UPDATE public.poker_games SET paused = FALSE, pause_deadline = NULL, paused_turn_remaining_s = NULL, afk_pause_for = NULL, afk_pause_name = NULL, afk_warning = NULL, turn_deadline = now() + (COALESCE(v_remaining_s, 30) || ' seconds')::interval WHERE id = _game_id;
    WHEN 'ludo' THEN UPDATE public.ludo_games SET paused = FALSE, pause_deadline = NULL, afk_pause_for = NULL, afk_pause_name = NULL, afk_warning = NULL, state = jsonb_set(state, '{turn_started_at}', to_jsonb(now()::text), true) WHERE id = _game_id;
  END CASE;
END $function$
;

CREATE OR REPLACE FUNCTION public.gen_referral_code()
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE c TEXT;
BEGIN
  LOOP
    c := upper(substring(replace(gen_random_uuid()::text,'-',''),1,7));
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE referral_code = c) THEN
      RETURN c;
    END IF;
  END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION public.gen_unique_code()
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE c TEXT;
BEGIN
  LOOP
    c := 'LD' || upper(substring(replace(gen_random_uuid()::text,'-',''),1,5));
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE unique_code = c) THEN RETURN c; END IF;
  END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION public.get_ai_assistant_settings()
 RETURNS TABLE(enabled boolean, context text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT COALESCE(ai_assistant_enabled, true), ai_assistant_context
  FROM public.app_settings WHERE id = 1;
$function$
;

CREATE OR REPLACE FUNCTION public.get_daily_bonus_status()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_profile record; v_settings record; v_today date := CURRENT_DATE;
BEGIN
  SELECT last_daily_claim, daily_streak INTO v_profile FROM public.profiles WHERE id = v_uid;
  SELECT daily_bonus_enabled, daily_bonus_amount_ar, daily_bonus_streak_bonus INTO v_settings FROM public.app_settings WHERE id = 1;
  RETURN jsonb_build_object(
    'enabled',     COALESCE(v_settings.daily_bonus_enabled, true),
    'base_amount', COALESCE(v_settings.daily_bonus_amount_ar, 500),
    'streak',      COALESCE(v_profile.daily_streak, 0),
    'last_claim',  v_profile.last_daily_claim,
    'can_claim',   COALESCE(v_settings.daily_bonus_enabled, true) AND (v_profile.last_daily_claim IS NULL OR v_profile.last_daily_claim < v_today),
    'next_claim',  CASE WHEN v_profile.last_daily_claim = v_today THEN (v_today + 1)::text ELSE v_today::text END,
    'streak_bonus',COALESCE(v_settings.daily_bonus_streak_bonus, true));
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_email_by_phone(_phone text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT email FROM public.profiles WHERE phone = trim(_phone) LIMIT 1;
$function$
;

CREATE OR REPLACE FUNCTION public.get_full_history(_uid uuid, _limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_caller uuid := auth.uid();
BEGIN
  IF _uid <> v_caller AND NOT public.has_role(v_caller, 'admin'::public.app_role) THEN RAISE EXCEPTION 'Accès refusé'; END IF;
  RETURN jsonb_build_object(
    'transactions', (SELECT jsonb_agg(row_to_json(t) ORDER BY t.created_at DESC) FROM (SELECT * FROM public.transactions WHERE user_id = _uid ORDER BY created_at DESC LIMIT _limit) t),
    'deposits',     (SELECT jsonb_agg(row_to_json(d) ORDER BY d.created_at DESC) FROM (SELECT * FROM public.deposits     WHERE user_id = _uid ORDER BY created_at DESC LIMIT _limit) d),
    'withdrawals',  (SELECT jsonb_agg(row_to_json(w) ORDER BY w.created_at DESC) FROM (SELECT * FROM public.withdrawals  WHERE user_id = _uid ORDER BY created_at DESC LIMIT _limit) w));
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_game_commission(_game text)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v numeric; v_global numeric;
BEGIN
  SELECT
    CASE lower(_game)
      WHEN 'ludo'       THEN ludo_commission_pct
      WHEN 'chess'      THEN chess_commission_pct
      WHEN 'domino'     THEN domino_commission_pct
      WHEN 'rami'       THEN rami_commission_pct
      WHEN 'fanorona'   THEN fanorona_commission_pct
      WHEN 'poker'      THEN poker_commission_pct
      WHEN 'billiard'   THEN billiard_commission_pct
      WHEN 'tournament' THEN tournament_commission_pct
      ELSE NULL
    END,
    game_commission_pct
  INTO v, v_global
  FROM public.app_settings WHERE id = 1;

  RETURN COALESCE(v, v_global, 10);
END $function$
;

CREATE OR REPLACE FUNCTION public.get_legal_texts()
 RETURNS TABLE(terms_html text, privacy_html text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT COALESCE(terms_html,''), COALESCE(privacy_html,'')
  FROM public.app_settings WHERE id = 1;
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_referrals()
 RETURNS TABLE(id uuid, pseudo text, created_at timestamp with time zone, phone_verified boolean, referral_unlocked boolean, bonus_amount numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT p.id, p.pseudo, p.created_at, p.phone_verified, p.referral_unlocked,
    COALESCE((
      SELECT SUM(t.amount) FROM public.transactions t
      WHERE t.user_id = auth.uid() AND t.type = 'referral'
        AND (t.note ILIKE '%' || p.id::text || '%' OR t.note ILIKE '%' || p.pseudo || '%')
    ), 0)::numeric AS bonus_amount
  FROM public.profiles p
  WHERE p.referred_by = auth.uid()
  ORDER BY p.created_at DESC;
$function$
;

CREATE OR REPLACE FUNCTION public.get_player_achievements(_uid uuid)
 RETURNS TABLE(key text, label text, description text, icon text, xp_reward integer, earned_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT a.key, a.label, a.description, a.icon, a.xp_reward, pa.earned_at
  FROM public.achievements a
  JOIN public.player_achievements pa ON pa.achievement_key = a.key AND pa.user_id = _uid
  ORDER BY pa.earned_at DESC;
$function$
;

CREATE OR REPLACE FUNCTION public.get_poker_hand_history(_user_id uuid, _limit integer DEFAULT 10)
 RETURNS SETOF poker_hand_history
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT h.* FROM public.poker_hand_history h
  WHERE h.players @> jsonb_build_array(jsonb_build_object('user_id', _user_id::text))
     OR EXISTS (
       SELECT 1 FROM jsonb_array_elements(h.players) e
       WHERE (e->>'user_id')::uuid = _user_id
     )
  ORDER BY h.created_at DESC
  LIMIT COALESCE(_limit, 10);
$function$
;

-- ═══════════ 0007_functions_10.sql ═══════════
-- 0007_functions_10.sql
-- Fonctions et procédures (10/12)

CREATE OR REPLACE FUNCTION public.get_public_help_texts()
 RETURNS TABLE(signup_help text, reset_help text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT COALESCE(signup_help_html,''), COALESCE(password_reset_help_html,'')
  FROM public.app_settings WHERE id = 1;
$function$
;

CREATE OR REPLACE FUNCTION public.get_public_profile(_id uuid)
 RETURNS TABLE(id uuid, pseudo text, avatar_url text, unique_code text, created_at timestamp with time zone, player_level integer, total_wins integer, total_games integer, daily_streak integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    p.id, p.pseudo, p.avatar_url, p.unique_code, p.created_at,
    COALESCE(p.player_level, 1),
    COALESCE(p.total_wins, 0),
    COALESCE(p.total_games, 0),
    COALESCE(p.daily_streak, 0)
  FROM public.profiles p
  WHERE p.id = _id AND (p.is_banned = false OR p.is_banned IS NULL);
$function$
;

CREATE OR REPLACE FUNCTION public.get_public_profiles_min(_ids uuid[])
 RETURNS TABLE(id uuid, pseudo text, avatar_url text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT p.id, p.pseudo, p.avatar_url
  FROM public.profiles p
  WHERE p.id = ANY(_ids);
$function$
;

CREATE OR REPLACE FUNCTION public.get_referral_dashboard()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_stats public.v_referral_stats%ROWTYPE;
  v_refs jsonb; v_events jsonb; v_settings jsonb;
  v_rank int; v_flags int;
  v_max int;
BEGIN
  SELECT COALESCE(referral_stake_max, 10) INTO v_max FROM public.referral_settings WHERE id=1;
  SELECT * INTO v_stats FROM public.v_referral_stats WHERE referrer_id = v_uid;
  SELECT jsonb_agg(jsonb_build_object(
    'id', p.id, 'pseudo', p.pseudo, 'avatar_url', p.avatar_url,
    'created_at', p.created_at,
    'phone_verified', p.phone_verified,
    'referral_unlocked', p.referral_unlocked,
    'referral_stake_count', COALESCE(p.referral_stake_count, 0),
    'first_deposit_amount', COALESCE(p.first_deposit_amount, 0),
    'total_earned', COALESCE((SELECT SUM(re.reward_amount) FROM public.referral_events re WHERE re.referee_id=p.id AND re.referrer_id=v_uid),0)
  ) ORDER BY p.created_at DESC)
  INTO v_refs FROM public.profiles p WHERE p.referred_by = v_uid;

  WITH ordered AS (
    SELECT re.id, re.event_type, re.reward_amount, re.note, re.created_at,
           re.referee_id,
           ROW_NUMBER() OVER (PARTITION BY re.referee_id, re.event_type ORDER BY re.created_at ASC) AS match_index
    FROM public.referral_events re
    WHERE re.referrer_id = v_uid
  )
  SELECT jsonb_agg(jsonb_build_object(
    'id', o.id, 'event_type', o.event_type,
    'reward_amount', o.reward_amount, 'note', o.note,
    'created_at', o.created_at, 'referee_pseudo', p.pseudo,
    'match_index', CASE WHEN o.event_type = 'stake_commission' THEN o.match_index ELSE NULL END,
    'match_max', v_max
  ) ORDER BY o.created_at DESC)
  INTO v_events FROM ordered o
  JOIN public.profiles p ON p.id = o.referee_id;

  SELECT jsonb_build_object(
    'deposit_bonus_pct', deposit_bonus_pct, 'deposit_min_ar', deposit_min_ar,
    'tier_silver_min', tier_silver_min, 'tier_gold_min', tier_gold_min, 'tier_diamond_min', tier_diamond_min,
    'tier_silver_mult', tier_silver_mult, 'tier_gold_mult', tier_gold_mult, 'tier_diamond_mult', tier_diamond_mult,
    'campaign_label', campaign_label, 'campaign_expires_at', campaign_expires_at,
    'campaign_bonus_pct', campaign_bonus_pct, 'enabled', enabled,
    'stake_commission_pct', stake_commission_pct,
    'referral_stake_max', referral_stake_max
  ) INTO v_settings FROM public.referral_settings WHERE id=1;
  SELECT rank INTO v_rank FROM public.get_referral_leaderboard(200) WHERE referrer_id = v_uid;
  SELECT COUNT(*) INTO v_flags FROM public.referral_fraud_flags WHERE referrer_id=v_uid AND status='pending';
  RETURN jsonb_build_object(
    'referral_code', (SELECT referral_code FROM public.profiles WHERE id=v_uid),
    'stats', to_jsonb(v_stats),
    'referrals', COALESCE(v_refs, '[]'::jsonb),
    'events', COALESCE(v_events,'[]'::jsonb),
    'settings', v_settings, 'rank', v_rank, 'pending_flags', v_flags);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_referral_leaderboard(_limit integer DEFAULT 50)
 RETURNS TABLE(rank integer, referrer_id uuid, pseudo text, avatar_url text, active_referrals bigint, total_earned_ar numeric, tier text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    (row_number() OVER (ORDER BY vr.active_referrals DESC, vr.total_earned_ar DESC))::int,
    vr.referrer_id, p.pseudo, p.avatar_url,
    vr.active_referrals, vr.total_earned_ar, vr.tier
  FROM public.v_referral_stats vr
  JOIN public.profiles p ON p.id = vr.referrer_id
  WHERE vr.active_referrals > 0 AND (p.is_banned = false OR p.is_banned IS NULL)
  ORDER BY vr.active_referrals DESC, vr.total_earned_ar DESC
  LIMIT _limit;
$function$
;

CREATE OR REPLACE FUNCTION public.gi_touch_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$function$
;

CREATE OR REPLACE FUNCTION public.hall_of_fame()
 RETURNS TABLE(id uuid, name text, mode text, season integer, finished_at timestamp with time zone, winner_id uuid, winner_pseudo text, top3 jsonb, prize_pool numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT t.id, t.name, t.mode, t.season, t.finished_at,
         t.winner_id, p.pseudo AS winner_pseudo, t.top3, t.prize_pool
  FROM public.tournaments t
  LEFT JOIN public.profiles p ON p.id = t.winner_id
  WHERE t.status = 'finished'
    AND (COALESCE(t.is_test, false) = false OR public.is_admin())
  ORDER BY t.finished_at DESC;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_pseudo TEXT;
  v_ref_code TEXT;
  v_referred_by UUID;
  v_input_ref TEXT;
  v_bonus NUMERIC;
  v_phone TEXT;
BEGIN
  v_phone := COALESCE(NEW.phone, NEW.raw_user_meta_data->>'phone');
  v_pseudo := COALESCE(
    NEW.raw_user_meta_data->>'pseudo',
    NULLIF(split_part(COALESCE(NEW.email,''),'@',1),''),
    'user_' || substr(NEW.id::text, 1, 8)
  );
  v_input_ref := NEW.raw_user_meta_data->>'referral_code';
  v_ref_code := public.gen_referral_code();

  IF v_input_ref IS NOT NULL AND v_input_ref <> '' THEN
    SELECT id INTO v_referred_by FROM public.profiles WHERE referral_code = upper(v_input_ref);
  END IF;

  SELECT signup_bonus INTO v_bonus FROM public.app_settings WHERE id = 1;

  INSERT INTO public.profiles(id, pseudo, email, phone, referral_code, referred_by, balance_ar)
  VALUES (NEW.id, v_pseudo, NEW.email, v_phone, v_ref_code, v_referred_by, COALESCE(v_bonus,0))
  ON CONFLICT (id) DO NOTHING;

  IF COALESCE(v_bonus,0) > 0 THEN
    INSERT INTO public.transactions(user_id,type,amount,note) VALUES (NEW.id,'bonus',v_bonus,'Bonus inscription');
  END IF;

  IF lower(COALESCE(NEW.email,'')) = 'soavinapierrit@gmail.com' THEN
    INSERT INTO public.user_roles(user_id, role) VALUES (NEW.id, 'admin') ON CONFLICT DO NOTHING;
  ELSE
    INSERT INTO public.user_roles(user_id, role) VALUES (NEW.id, 'user') ON CONFLICT DO NOTHING;
  END IF;

  RETURN NEW;
END $function$
;

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role app_role)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id=_user_id AND role=_role)
$function$
;

CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT public.has_role(auth.uid(),'admin')
$function$
;

CREATE OR REPLACE FUNCTION public.is_game_disabled(_slug text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT COALESCE(
    (SELECT (games_disabled) ? _slug FROM public.app_settings WHERE id = 1),
    false);
$function$
;

CREATE OR REPLACE FUNCTION public.join_game(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid UUID := auth.uid(); v_balance NUMERIC; v_game public.ludo_games%ROWTYPE;
  v_count INT; v_slot INT; v_color TEXT; v_paused BOOLEAN; v_banned BOOLEAN; v_name text;
  v_colors_2 TEXT[] := ARRAY['red','yellow'];
  v_colors_3 TEXT[] := ARRAY['red','green','yellow'];
  v_colors_4 TEXT[] := ARRAY['red','green','yellow','blue'];
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  PERFORM public.cleanup_stale_open_games();
  SELECT paused INTO v_paused FROM public.app_settings WHERE id=1;
  IF COALESCE(v_paused,FALSE) THEN RAISE EXCEPTION 'Application en pause'; END IF;
  SELECT banned, pseudo INTO v_banned, v_name FROM public.profiles WHERE id=v_uid;
  IF COALESCE(v_banned,FALSE) THEN RAISE EXCEPTION 'Compte banni'; END IF;
  SELECT * INTO v_game FROM public.ludo_games WHERE id=_game_id FOR UPDATE;
  IF v_game.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  IF v_game.status <> 'open' THEN RAISE EXCEPTION 'Partie déjà commencée'; END IF;
  IF EXISTS (SELECT 1 FROM public.ludo_participants WHERE game_id=_game_id AND user_id=v_uid) THEN
    RAISE EXCEPTION 'Déjà inscrit'; END IF;
  SELECT balance_ar INTO v_balance FROM public.profiles WHERE id=v_uid FOR UPDATE;
  IF v_balance < v_game.stake THEN RAISE EXCEPTION 'Solde insuffisant'; END IF;
  SELECT count(*) INTO v_count FROM public.ludo_participants WHERE game_id=_game_id;
  IF v_count >= v_game.max_players THEN RAISE EXCEPTION 'Partie pleine'; END IF;
  v_slot := v_count;
  v_color := CASE v_game.max_players
    WHEN 2 THEN v_colors_2[v_slot+1]
    WHEN 3 THEN v_colors_3[v_slot+1]
    ELSE v_colors_4[v_slot+1] END;
  INSERT INTO public.ludo_participants(game_id,user_id,slot,color,display_name)
    VALUES (_game_id, v_uid, v_slot, v_color, v_name);
  UPDATE public.profiles SET balance_ar = balance_ar - v_game.stake WHERE id=v_uid;
  UPDATE public.ludo_games SET pot = pot + v_game.stake WHERE id=_game_id;
  INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
    VALUES (v_uid,'stake',-v_game.stake,_game_id,'Mise rejoindre partie');
END $function$
;

CREATE OR REPLACE FUNCTION public.join_game_by_code(_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_id UUID;
BEGIN
  SELECT id INTO v_id FROM public.ludo_games WHERE room_code = upper(_code) AND status='open';
  IF v_id IS NULL THEN RAISE EXCEPTION 'Code de partie invalide'; END IF;
  PERFORM public.join_game(v_id);
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.leaderboard_winners(_period text DEFAULT 'all'::text, _limit integer DEFAULT 20, _slug text DEFAULT NULL::text)
 RETURNS TABLE(rank integer, user_id uuid, name text, avatar_url text, wins bigint, total_won numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  WITH bound AS (
    SELECT CASE _period
      WHEN 'week'  THEN now() - interval '7 days'
      WHEN 'month' THEN now() - interval '30 days'
      ELSE 'epoch'::timestamptz
    END AS since
  ),
  raw AS (
    SELECT g.winner_id AS uid, NULLIF(trim(pp.display_name),'') AS dn,
           g.pot * (1 - g.commission_pct/100.0) AS won
      FROM ludo_games g JOIN ludo_participants pp ON pp.game_id=g.id AND pp.user_id=g.winner_id, bound
      WHERE (_slug IS NULL OR _slug = 'all' OR _slug = 'ludo')
        AND g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at,g.created_at) >= bound.since
    UNION ALL
    SELECT g.winner_id, NULLIF(trim(pp.display_name),''),
           g.pot * (1 - COALESCE(g.commission_pct,0)/100.0)
      FROM domino_games g JOIN domino_participants pp ON pp.game_id=g.id AND pp.user_id=g.winner_id, bound
      WHERE (_slug IS NULL OR _slug = 'all' OR _slug = 'domino')
        AND g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at,g.created_at) >= bound.since
    UNION ALL
    SELECT g.winner_id, NULLIF(trim(pp.display_name),''),
           g.pot * (1 - COALESCE(g.commission_pct,0)/100.0)
      FROM fanorona_games g JOIN fanorona_participants pp ON pp.game_id=g.id AND pp.user_id=g.winner_id, bound
      WHERE (_slug IS NULL OR _slug = 'all' OR _slug = 'fanorona')
        AND g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at,g.created_at) >= bound.since
    UNION ALL
    SELECT g.winner_id, NULLIF(trim(pp.display_name),''),
           g.pot * (1 - COALESCE(g.commission_pct,0)/100.0)
      FROM rami_games g JOIN rami_participants pp ON pp.game_id=g.id AND pp.user_id=g.winner_id, bound
      WHERE (_slug IS NULL OR _slug = 'all' OR _slug = 'rami')
        AND g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at,g.created_at) >= bound.since
    UNION ALL
    SELECT g.winner_id, NULL::text,
           g.stake * 2 * (1 - COALESCE((SELECT commission_pct FROM app_settings WHERE id=1),0)/100.0)
      FROM chess_games g, bound
      WHERE (_slug IS NULL OR _slug = 'all' OR _slug = 'chess')
        AND g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at,g.created_at) >= bound.since
    UNION ALL
    SELECT g.winner_id, NULLIF(trim(pp.bot_name),''),
           g.pot * (1 - COALESCE(g.commission_pct,0)/100.0)
      FROM poker_games g JOIN poker_players pp ON pp.game_id=g.id AND pp.user_id=g.winner_id, bound
      WHERE (_slug IS NULL OR _slug = 'all' OR _slug = 'poker')
        AND g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at,g.created_at) >= bound.since
  ),
  alias_admins AS (
    SELECT DISTINCT a.admin_id AS uid FROM public.admin_aliases a
    UNION SELECT ap.admin_id FROM public.admin_persona ap
    UNION SELECT p.id FROM public.profiles p WHERE lower(p.email) = 'soavinapierrit@gmail.com'
  ),
  filtered AS (
    SELECT r.uid, r.dn, r.won,
           (r.uid IN (SELECT uid FROM alias_admins)) AS is_alias_admin
      FROM raw r
     WHERE NOT EXISTS (SELECT 1 FROM public.profiles pb WHERE pb.id = r.uid AND (pb.is_bot = true OR pb.leaderboard_hidden = true))
  ),
  kept AS (
    -- Les comptes à alias n'apparaissent JAMAIS sous leur identité réelle :
    -- seules les parties jouées sous un alias enregistré comptent, une ligne par alias.
    SELECT f.uid, f.dn, f.won, ('alias:' || f.dn) AS key
      FROM filtered f
     WHERE f.is_alias_admin
       AND f.dn IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.admin_aliases a WHERE a.admin_id = f.uid AND a.pseudo = f.dn)
    UNION ALL
    SELECT f.uid, f.dn, f.won, f.uid::text
      FROM filtered f
     WHERE NOT f.is_alias_admin
  ),
  agg AS (
    SELECT key,
           MIN(uid::text)::uuid AS uid,
           COUNT(*) AS wins,
           SUM(won) AS total_won,
           MAX(dn) AS dn,
           bool_or(key LIKE 'alias:%') AS is_alias
    FROM kept
    GROUP BY key
  )
  SELECT ROW_NUMBER() OVER (ORDER BY total_won DESC NULLS LAST, wins DESC)::int AS rank,
         a.uid AS user_id,
         COALESCE(a.dn, p.pseudo, 'Joueur') AS name,
         CASE WHEN a.is_alias
              THEN (SELECT al.avatar_url FROM public.admin_aliases al WHERE al.admin_id = a.uid AND al.pseudo = a.dn LIMIT 1)
              ELSE p.avatar_url END AS avatar_url,
         a.wins,
         a.total_won
    FROM agg a
    LEFT JOIN public.profiles p ON p.id = a.uid
    ORDER BY total_won DESC NULLS LAST, wins DESC
    LIMIT LEAST(COALESCE(_limit, 20), 100);
$function$
;

CREATE OR REPLACE FUNCTION public.list_live_games()
 RETURNS TABLE(id uuid, max_players integer, stake numeric, pot numeric, players_count integer, spectators_count integer, started_at timestamp with time zone, mode text, game_type text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT g.id, g.max_players, g.stake, g.pot,
    (SELECT count(*)::int FROM public.ludo_participants p WHERE p.game_id=g.id),
    (SELECT count(*)::int FROM public.game_spectators s WHERE s.game_id=g.id),
    g.started_at, COALESCE(g.mode,'classic')::text, 'ludo'::text
  FROM public.ludo_games g
  WHERE g.status='playing'
    AND NOT (COALESCE(g.paused,FALSE) AND EXISTS (
      SELECT 1 FROM public.ludo_participants pp WHERE pp.game_id=g.id AND pp.is_bot=TRUE
    ))
  UNION ALL
  SELECT g.id, g.max_players, g.stake, g.pot,
    (SELECT count(*)::int FROM public.domino_participants p WHERE p.game_id=g.id),
    (SELECT count(*)::int FROM public.game_spectators s WHERE s.game_id=g.id),
    g.started_at, COALESCE(g.mode,'classic')::text, 'domino'::text
  FROM public.domino_games g
  WHERE g.status='playing'
    AND NOT (COALESCE(g.paused,FALSE) AND EXISTS (
      SELECT 1 FROM public.domino_participants pp WHERE pp.game_id=g.id AND pp.is_bot=TRUE
    ))
  UNION ALL
  SELECT g.id, 2, g.stake, g.pot, 2,
    (SELECT count(*)::int FROM public.game_spectators s WHERE s.game_id=g.id),
    g.started_at, 'classic'::text, 'chess'::text
  FROM public.chess_games g
  WHERE g.status='playing'
    AND NOT (COALESCE(g.paused,FALSE) AND EXISTS (
      SELECT 1 FROM public.profiles pr
       WHERE pr.id IN (g.white_id, g.black_id) AND COALESCE(pr.is_bot,FALSE)=TRUE
    ))
  UNION ALL
  SELECT g.id, g.max_players, g.stake, g.pot,
    (SELECT count(*)::int FROM public.rami_participants p WHERE p.game_id=g.id),
    (SELECT count(*)::int FROM public.game_spectators s WHERE s.game_id=g.id),
    g.started_at, COALESCE(g.joker_mode,'classique')::text, 'rami'::text
  FROM public.rami_games g
  WHERE g.status='playing'
    AND NOT (COALESCE(g.paused,FALSE) AND EXISTS (
      SELECT 1 FROM public.rami_participants pp WHERE pp.game_id=g.id AND pp.is_bot=TRUE
    ))
  ORDER BY 6 DESC, 7 ASC;
$function$
;

CREATE OR REPLACE FUNCTION public.list_players_for_dm()
 RETURNS TABLE(id uuid, pseudo text, avatar_url text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT p.id, p.pseudo, p.avatar_url FROM public.profiles p
  WHERE p.id <> auth.uid() ORDER BY p.pseudo ASC
$function$
;

CREATE OR REPLACE FUNCTION public.list_players_for_dm(_search text DEFAULT NULL::text, _limit integer DEFAULT 50)
 RETURNS TABLE(id uuid, pseudo text, avatar_url text, unique_code text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'auth'; END IF;
  RETURN QUERY
    SELECT p.id, p.pseudo, p.avatar_url, p.unique_code
    FROM public.profiles p
    WHERE p.id <> auth.uid()
      AND COALESCE(p.banned, FALSE) = FALSE
      AND COALESCE(p.is_bot, FALSE) = FALSE
      AND (_search IS NULL OR _search = '' OR p.pseudo ILIKE '%' || _search || '%')
    ORDER BY p.pseudo ASC
    LIMIT LEAST(COALESCE(_limit, 50), 100);
END $function$
;

CREATE OR REPLACE FUNCTION public.list_public_open_games()
 RETURNS TABLE(id uuid, game_slug text, max_players integer, stake numeric, pot numeric, room_code text, players_count integer, is_private boolean, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT g.id, 'ludo'::text, g.max_players, g.stake, g.pot, g.room_code,
    (SELECT count(*)::int FROM public.ludo_participants p WHERE p.game_id=g.id),
    g.is_private, g.created_at
  FROM public.ludo_games g
  WHERE g.status='open' AND g.is_private=false
    AND (SELECT count(*) FROM public.ludo_participants p WHERE p.game_id=g.id) < g.max_players

  UNION ALL
  SELECT g.id, 'domino', g.max_players, g.stake, g.pot, g.room_code,
    (SELECT count(*)::int FROM public.domino_participants p WHERE p.game_id=g.id),
    g.is_private, g.created_at
  FROM public.domino_games g
  WHERE g.status='open' AND g.is_private=false
    AND (SELECT count(*) FROM public.domino_participants p WHERE p.game_id=g.id) < g.max_players

  UNION ALL
  SELECT g.id, 'fanorona', 2, g.stake, g.pot, g.room_code,
    (SELECT count(*)::int FROM public.fanorona_participants p WHERE p.game_id=g.id),
    g.is_private, g.created_at
  FROM public.fanorona_games g
  WHERE g.status='open' AND g.is_private=false
    AND (SELECT count(*) FROM public.fanorona_participants p WHERE p.game_id=g.id) < 2

  UNION ALL
  SELECT g.id, 'chess', 2, g.stake, g.pot, g.room_code,
    ((CASE WHEN g.white_id IS NULL THEN 0 ELSE 1 END) + (CASE WHEN g.black_id IS NULL THEN 0 ELSE 1 END)),
    g.is_private, g.created_at
  FROM public.chess_games g
  WHERE g.status='open' AND g.is_private=false
    AND (g.white_id IS NULL OR g.black_id IS NULL)

  UNION ALL
  SELECT g.id, 'rami', g.max_players, g.stake, g.pot, g.room_code,
    (SELECT count(*)::int FROM public.rami_participants p WHERE p.game_id=g.id),
    g.is_private, g.created_at
  FROM public.rami_games g
  WHERE g.status='open' AND g.is_private=false
    AND (SELECT count(*) FROM public.rami_participants p WHERE p.game_id=g.id) < g.max_players

  UNION ALL
  SELECT g.id, 'poker', g.max_players, g.stake, g.pot, g.room_code,
    (SELECT count(*)::int FROM public.poker_players p WHERE p.game_id=g.id),
    g.is_private, g.created_at
  FROM public.poker_games g
  WHERE g.status='open' AND g.is_private=false
    AND (SELECT count(*) FROM public.poker_players p WHERE p.game_id=g.id) < g.max_players

  ORDER BY created_at DESC;
$function$
;

CREATE OR REPLACE FUNCTION public.list_tournaments(_status text DEFAULT NULL::text, _game_slug text DEFAULT NULL::text, _limit integer DEFAULT 100)
 RETURNS SETOF tournaments
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT * FROM public.tournaments
   WHERE (_status IS NULL OR status = _status)
     AND (_game_slug IS NULL OR game_slug = _game_slug)
     AND (status <> 'draft' OR public.is_admin())
   ORDER BY created_at DESC LIMIT _limit;
$function$
;

CREATE OR REPLACE FUNCTION public.ludo_bot_step(_game_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g public.ludo_games%ROWTYPE;
  v_slot int; v_isbot boolean; v_dice int; v_playable jsonb;
  v_pawn_idx int; v_count int;
  v_phase text; v_phase_at timestamptz; v_spin_ms int; v_elapsed_ms int;
BEGIN
  SELECT * INTO g FROM public.ludo_games WHERE id=_game_id;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  IF g.status <> 'playing' THEN RETURN g.state; END IF;
  IF COALESCE(g.paused, FALSE) THEN RETURN g.state; END IF;
  v_slot := COALESCE((g.state->>'turn_slot')::int, 0);
  SELECT is_bot INTO v_isbot FROM public.ludo_participants WHERE game_id=_game_id AND slot=v_slot;
  IF NOT COALESCE(v_isbot, FALSE) THEN RETURN g.state; END IF;
  IF NOT COALESCE((g.state->>'must_move')::boolean, FALSE) THEN
    v_phase   := g.state->>'phase';
    v_spin_ms := COALESCE((g.state->>'spin_ms')::int, 0);
    IF v_phase = 'spinning' AND v_spin_ms > 0 THEN
      v_phase_at := NULLIF(g.state->>'phase_started_at','')::timestamptz;
      IF v_phase_at IS NOT NULL THEN
        v_elapsed_ms := (EXTRACT(EPOCH FROM (now() - v_phase_at)) * 1000)::int;
        IF v_elapsed_ms < v_spin_ms THEN RETURN g.state; END IF;
      END IF;
    END IF;
    RETURN public.ludo_roll(_game_id);
  END IF;
  v_dice := (g.state->>'dice')::int;
  v_playable := public._ludo_playable_pawns(g.state->'pawns', v_slot, v_dice);
  v_count := jsonb_array_length(COALESCE(v_playable, '[]'::jsonb));
  IF v_count = 0 THEN
    PERFORM public.ludo_pass(_game_id);
    SELECT state INTO g.state FROM public.ludo_games WHERE id=_game_id;
    RETURN g.state;
  END IF;
  v_pawn_idx := (v_playable->0)::int;
  DECLARE
    ii int; idx int; pawn jsonb; best_step int := -1;
  BEGIN
    IF v_dice = 6 THEN
      FOR ii IN 0..(v_count-1) LOOP
        idx := (v_playable->ii)::int;
        pawn := g.state->'pawns'->v_slot::text->idx;
        IF pawn->>'s' = 'yard' THEN v_pawn_idx := idx; EXIT; END IF;
      END LOOP;
    END IF;
    IF v_pawn_idx = (v_playable->0)::int THEN
      FOR ii IN 0..(v_count-1) LOOP
        idx := (v_playable->ii)::int;
        pawn := g.state->'pawns'->v_slot::text->idx;
        IF pawn->>'s' = 'track' THEN
          IF (pawn->>'k')::int > best_step THEN
            best_step := (pawn->>'k')::int; v_pawn_idx := idx;
          END IF;
        END IF;
      END LOOP;
    END IF;
  END;
  RETURN public.ludo_move(_game_id, v_pawn_idx);
END $function$
;

CREATE OR REPLACE FUNCTION public.ludo_check_timeout(_game_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g public.ludo_games%ROWTYPE; st jsonb; v_slot int; v_started timestamptz;
  v_uid uuid; v_isbot boolean; v_secs int;
BEGIN
  SELECT * INTO g FROM public.ludo_games WHERE id=_game_id FOR UPDATE;
  IF g.status <> 'playing' THEN RETURN g.state; END IF;
  st := g.state; v_slot := (st->>'turn_slot')::INT;
  SELECT user_id, is_bot INTO v_uid, v_isbot
    FROM public.ludo_participants WHERE game_id=_game_id AND slot=v_slot;
  SELECT COALESCE(turn_seconds,30) INTO v_secs FROM public.app_settings WHERE id=1;
  v_started := (st->>'turn_started_at')::timestamptz;
  IF now() - v_started < (v_secs || ' seconds')::interval THEN RETURN st; END IF;

  -- Déplacement automatique : uniquement si le dé a déjà été lancé.
  IF NOT COALESCE(v_isbot,false)
     AND COALESCE((st->>'must_move')::boolean, false)
     AND COALESCE(g.auto_move, false) THEN
    IF public._ludo_auto_move(_game_id, v_slot) THEN
      SELECT state INTO st FROM public.ludo_games WHERE id=_game_id;
      RETURN st;
    END IF;
  END IF;

  IF NOT v_isbot AND NOT (st->>'must_move')::BOOLEAN THEN
    UPDATE public.ludo_participants SET afk_t1 = afk_t1 + 1 WHERE game_id=_game_id AND slot=v_slot;
  END IF;
  IF NOT v_isbot AND (st->>'must_move')::BOOLEAN THEN
    UPDATE public.ludo_participants SET afk_t2 = afk_t2 + 1 WHERE game_id=_game_id AND slot=v_slot;
  END IF;

  st := jsonb_set(st,'{turn_slot}', to_jsonb(public._ludo_next_slot(_game_id, v_slot, g.max_players)));
  st := jsonb_set(st,'{dice}','null'::jsonb);
  st := jsonb_set(st,'{must_move}','false'::jsonb);
  st := jsonb_set(st,'{turn_started_at}', to_jsonb(to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"')));
  st := jsonb_set(st,'{last_event}', to_jsonb('timeout'::text));
  UPDATE public.ludo_games SET state=st, current_turn=(st->>'turn_slot')::INT WHERE id=_game_id;
  IF NOT v_isbot THEN PERFORM public._ludo_check_afk(_game_id, v_slot); END IF;
  RETURN st;
END $function$
;

CREATE OR REPLACE FUNCTION public.ludo_cleanup_empty_rooms()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_count int;
BEGIN
  WITH d AS (
    DELETE FROM public.ludo_games g
    WHERE g.status='open' AND NOT EXISTS (SELECT 1 FROM public.ludo_participants p WHERE p.game_id=g.id)
    RETURNING 1
  ) SELECT count(*) INTO v_count FROM d;
  RETURN v_count;
END $function$
;

CREATE OR REPLACE FUNCTION public.ludo_create_friends_game(_max_players integer, _stake numeric, _mode text DEFAULT 'classic'::text, _is_public boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_balance numeric;
  v_id uuid;
  v_mode text;
  v_code text;
  v_commission numeric;
  v_paused boolean;
  v_banned boolean;
  v_name text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  PERFORM public.cleanup_stale_open_games();
  SELECT paused INTO v_paused FROM public.app_settings WHERE id=1;
  IF COALESCE(v_paused, FALSE) THEN RAISE EXCEPTION 'Application en pause'; END IF;
  SELECT banned, pseudo INTO v_banned, v_name FROM public.profiles WHERE id=v_uid;
  IF COALESCE(v_banned, FALSE) THEN RAISE EXCEPTION 'Compte banni'; END IF;
  IF _max_players NOT BETWEEN 2 AND 4 THEN RAISE EXCEPTION 'Joueurs invalides'; END IF;
  IF _stake < 0 THEN RAISE EXCEPTION 'Mise invalide'; END IF;

  v_mode := CASE WHEN _mode = 'fast' THEN 'fast' ELSE 'classic' END;

  IF _stake > 0 THEN
    SELECT balance_ar INTO v_balance FROM public.profiles WHERE id = v_uid FOR UPDATE;
    IF v_balance < _stake THEN RAISE EXCEPTION 'Solde insuffisant'; END IF;
    UPDATE public.profiles SET balance_ar = balance_ar - _stake WHERE id = v_uid;
    INSERT INTO public.transactions(user_id, type, amount, note)
      VALUES (v_uid, 'ludo_stake', -_stake, 'Mise Ludo (amis)');
  END IF;

  SELECT game_commission_pct INTO v_commission FROM public.app_settings WHERE id=1;
  v_code := public._gen_room_code();

  INSERT INTO public.ludo_games(host_id, max_players, stake, pot, commission_pct, room_code, is_private, mode, status)
    VALUES (v_uid, _max_players, _stake, _stake, COALESCE(v_commission, 10), v_code, NOT COALESCE(_is_public, false), v_mode, 'open')
    RETURNING id INTO v_id;

  INSERT INTO public.ludo_participants(game_id, user_id, slot, color, display_name)
    VALUES (v_id, v_uid, 0, 'red', v_name);

  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.ludo_heartbeat(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid UUID := auth.uid(); v_slot int;
BEGIN
  IF v_uid IS NULL THEN RETURN; END IF;
  UPDATE public.ludo_participants SET last_seen=now()
    WHERE game_id=_game_id AND user_id=v_uid
    RETURNING slot INTO v_slot;
  IF v_slot IS NOT NULL THEN
    UPDATE public.ludo_games SET disconnect_until = disconnect_until - v_slot::text
      WHERE id=_game_id AND disconnect_until ? v_slot::text;
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.ludo_join(_game_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  g public.ludo_games%ROWTYPE;
  v_balance numeric;
  v_name text;
  v_count int;
  v_slot int;
  v_color text;
  v_colors4 text[] := ARRAY['red','blue','green','yellow'];
  v_colors3 text[] := ARRAY['red','green','yellow'];
  v_colors2 text[] := ARRAY['red','yellow'];
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Connexion requise'; END IF;
  SELECT * INTO g FROM public.ludo_games WHERE id = _game_id FOR UPDATE;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  IF g.status <> 'open' THEN RAISE EXCEPTION 'Partie non disponible'; END IF;

  IF EXISTS(SELECT 1 FROM public.ludo_participants WHERE game_id = _game_id AND user_id = v_uid) THEN
    RETURN _game_id;
  END IF;

  SELECT count(*) INTO v_count FROM public.ludo_participants WHERE game_id = _game_id;
  IF v_count >= g.max_players THEN RAISE EXCEPTION 'Partie pleine'; END IF;

  SELECT balance_ar, pseudo INTO v_balance, v_name FROM public.profiles WHERE id = v_uid;
  IF COALESCE(g.stake,0) > 0 AND COALESCE(v_balance,0) < g.stake THEN
    RAISE EXCEPTION 'Solde insuffisant';
  END IF;

  SELECT s INTO v_slot FROM generate_series(0, g.max_players-1) s
    WHERE s NOT IN (SELECT slot FROM public.ludo_participants WHERE game_id = _game_id)
    ORDER BY s LIMIT 1;

  IF g.max_players = 2 THEN v_color := v_colors2[v_slot + 1];
  ELSIF g.max_players = 3 THEN v_color := v_colors3[v_slot + 1];
  ELSE v_color := v_colors4[v_slot + 1];
  END IF;

  INSERT INTO public.ludo_participants(game_id, user_id, slot, color, display_name)
    VALUES (_game_id, v_uid, v_slot, v_color, COALESCE(v_name, 'Joueur'));

  IF COALESCE(g.stake,0) > 0 THEN
    UPDATE public.profiles SET balance_ar = balance_ar - g.stake WHERE id = v_uid;
    INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
      VALUES (v_uid, 'ludo_stake', -g.stake, _game_id, 'Rejoindre partie Ludo');
    UPDATE public.ludo_games SET pot = pot + g.stake WHERE id = _game_id;
  END IF;

  RETURN _game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.ludo_move(_game_id uuid, _pawn_idx integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE st jsonb; g public.ludo_games%ROWTYPE; v_uid UUID := auth.uid();
  v_slot INT; v_dice INT; v_user UUID; v_isbot BOOLEAN; v_max INT;
  pawn jsonb; pawn_state TEXT; pawn_step INT; new_step INT; new_state TEXT;
  start_idx INT; abs_cell INT; captured BOOLEAN := FALSE; bonus BOOLEAN := FALSE;
  finished BOOLEAN := FALSE; all_done BOOLEAN; winner_uid UUID;
  rec RECORD; other_pawns jsonb; op jsonb; op_step INT; op_start INT;
  i INT; j INT; arr jsonb; same_slot_count INT;
  v_captured_list jsonb := '[]'::jsonb; v_now text; v_seq int;
  v_qc int; v_finishers int; v_remaining int; v_next_rank int;
BEGIN
  SELECT * INTO g FROM public.ludo_games WHERE id=_game_id FOR UPDATE;
  IF g.status <> 'playing' THEN RAISE EXCEPTION 'Partie pas en cours'; END IF;
  st := g.state; v_slot := (st->>'turn_slot')::INT; v_max := g.max_players;
  SELECT user_id, is_bot INTO v_user, v_isbot FROM public.ludo_participants WHERE game_id=_game_id AND slot=v_slot;
  IF NOT v_isbot AND v_user <> v_uid THEN RAISE EXCEPTION 'Pas votre tour'; END IF;
  IF NOT (st->>'must_move')::BOOLEAN THEN RAISE EXCEPTION 'Lancez le dé d''abord'; END IF;
  v_dice := (st->>'dice')::INT;
  pawn := st->'pawns'->v_slot::text->_pawn_idx;
  IF pawn IS NULL THEN RAISE EXCEPTION 'Pion inconnu'; END IF;
  pawn_state := pawn->>'s'; pawn_step := (pawn->>'k')::INT;
  IF pawn_state = 'finished' THEN RAISE EXCEPTION 'Pion déjà arrivé'; END IF;
  IF pawn_state = 'yard' THEN
    IF v_dice <> 6 THEN RAISE EXCEPTION 'Sortie possible avec un 6'; END IF;
    new_state := 'track'; new_step := 0;
  ELSE
    new_step := pawn_step + v_dice;
    IF new_step > 56 THEN RAISE EXCEPTION 'Dépassement — chiffre exact requis pour entrer à l''arrivée'; END IF;
    IF new_step = 56 THEN new_state := 'finished'; finished := TRUE; ELSE new_state := 'track'; END IF;
  END IF;
  arr := st->'pawns'->v_slot::text;
  arr := jsonb_set(arr, ARRAY[_pawn_idx::text], jsonb_build_object('s', new_state, 'k', new_step));
  st := jsonb_set(st, ARRAY['pawns', v_slot::text], arr);
  IF new_state = 'track' AND new_step <= 50 THEN
    start_idx := public._ludo_start_for(_game_id, v_slot);
    abs_cell := (start_idx + new_step) % 52;
    IF NOT public._ludo_is_safe(abs_cell) THEN
      FOR rec IN SELECT slot FROM public.ludo_participants WHERE game_id=_game_id AND slot <> v_slot LOOP
        op_start := public._ludo_start_for(_game_id, rec.slot);
        other_pawns := st->'pawns'->rec.slot::text;
        same_slot_count := 0;
        FOR j IN 0..3 LOOP
          op := other_pawns->j;
          IF op->>'s' = 'track' THEN
            op_step := (op->>'k')::INT;
            IF op_step <= 50 AND ((op_start + op_step) % 52) = abs_cell THEN
              same_slot_count := same_slot_count + 1;
            END IF;
          END IF;
        END LOOP;
        IF same_slot_count = 1 THEN
          FOR j IN 0..3 LOOP
            op := other_pawns->j;
            IF op->>'s' = 'track' THEN
              op_step := (op->>'k')::INT;
              IF op_step <= 50 AND ((op_start + op_step) % 52) = abs_cell THEN
                other_pawns := jsonb_set(other_pawns, ARRAY[j::text], jsonb_build_object('s','yard','k',-1));
                captured := TRUE;
                v_captured_list := v_captured_list || jsonb_build_object('slot', rec.slot, 'pawn', j);
              END IF;
            END IF;
          END LOOP;
          st := jsonb_set(st, ARRAY['pawns', rec.slot::text], other_pawns);
        END IF;
      END LOOP;
    END IF;
  END IF;
  all_done := TRUE;
  FOR i IN 0..3 LOOP
    IF (st->'pawns'->v_slot::text->i->>'s') <> 'finished' THEN all_done := FALSE; END IF;
  END LOOP;
  UPDATE public.ludo_participants SET missed_turns=0 WHERE game_id=_game_id AND slot=v_slot;
  UPDATE public.ludo_games SET state=st WHERE id=_game_id;
  v_now := to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"');
  v_seq := COALESCE((st->>'turn_seq')::int, 0);
  PERFORM public._ludo_push_move(_game_id, jsonb_build_object(
    'seq', v_seq, 'slot', v_slot, 'pawn', _pawn_idx, 'dice', v_dice,
    'captured', v_captured_list, 'finished', finished, 'at', v_now
  ));

  IF all_done THEN
    -- Assign finish rank to this player
    SELECT COALESCE(MAX(finish_rank),0)+1 INTO v_next_rank
      FROM public.ludo_participants WHERE game_id=_game_id;
    UPDATE public.ludo_participants SET finish_rank = v_next_rank
      WHERE game_id=_game_id AND slot=v_slot;

    -- How many qualifiers does this game/match need?
    v_qc := 1;
    IF g.tournament_match_id IS NOT NULL THEN
      SELECT COALESCE(qualifiers_count,1) INTO v_qc FROM public.tournament_matches WHERE id = g.tournament_match_id;
    END IF;

    SELECT count(*) INTO v_finishers FROM public.ludo_participants
      WHERE game_id=_game_id AND finish_rank IS NOT NULL;
    SELECT count(*) INTO v_remaining FROM public.ludo_participants
      WHERE game_id=_game_id AND finish_rank IS NULL AND forfeited=FALSE;

    IF v_finishers >= v_qc OR v_remaining <= 1 THEN
      -- End game: winner is first finisher (rank 1)
      SELECT user_id INTO winner_uid FROM public.ludo_participants
        WHERE game_id=_game_id AND finish_rank=1;
      PERFORM public.finish_game(_game_id, winner_uid);
      SELECT state INTO st FROM public.ludo_games WHERE id=_game_id;
      RETURN st;
    ELSE
      -- Continue with next non-finished player
      RETURN public._ludo_advance_turn(
        _game_id, public._ludo_next_slot(_game_id, v_slot, v_max), 'home:continue'
      );
    END IF;
  END IF;

  bonus := (v_dice = 6) OR captured OR finished;
  IF NOT bonus THEN
    UPDATE public.ludo_participants SET consecutive_sixes=0 WHERE game_id=_game_id AND slot=v_slot;
  END IF;
  RETURN public._ludo_advance_turn(
    _game_id,
    CASE WHEN bonus THEN v_slot ELSE public._ludo_next_slot(_game_id, v_slot, v_max) END,
    CASE WHEN bonus THEN (CASE WHEN captured THEN 'capture' WHEN finished THEN 'home' ELSE 'six' END || ':rejoue') ELSE 'move' END
  );
END $function$
;

CREATE OR REPLACE FUNCTION public.ludo_pass(_game_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g public.ludo_games%ROWTYPE; st jsonb; v_slot INT; v_dice INT;
  v_uid UUID := auth.uid(); v_user UUID; v_isbot BOOLEAN; arr jsonb;
  pawn jsonb; i INT; pstate TEXT; pstep INT; has_move BOOLEAN := FALSE;
BEGIN
  SELECT * INTO g FROM public.ludo_games WHERE id=_game_id FOR UPDATE;
  IF g.status <> 'playing' THEN RAISE EXCEPTION 'Partie pas en cours'; END IF;
  st := g.state; v_slot := (st->>'turn_slot')::INT;
  SELECT user_id, is_bot INTO v_user, v_isbot FROM public.ludo_participants WHERE game_id=_game_id AND slot=v_slot;
  IF NOT v_isbot AND v_user <> v_uid THEN RAISE EXCEPTION 'Pas votre tour'; END IF;
  IF NOT (st->>'must_move')::BOOLEAN THEN RAISE EXCEPTION 'Lancez le dé d''abord'; END IF;
  v_dice := (st->>'dice')::INT;
  arr := st->'pawns'->v_slot::text;
  FOR i IN 0..3 LOOP
    pawn := arr->i; pstate := pawn->>'s'; pstep := (pawn->>'k')::INT;
    IF pstate='finished' THEN CONTINUE; END IF;
    IF pstate='yard' THEN
      IF v_dice = 6 THEN has_move := TRUE; EXIT; END IF;
    ELSE
      IF pstep + v_dice <= 56 THEN has_move := TRUE; EXIT; END IF;
    END IF;
  END LOOP;
  IF has_move THEN RAISE EXCEPTION 'Vous avez un coup possible'; END IF;
  RETURN public._ludo_advance_turn(_game_id, public._ludo_next_slot(_game_id, v_slot, g.max_players), 'pass');
END $function$
;

CREATE OR REPLACE FUNCTION public.ludo_purge_unready_rooms()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g RECORD;
  p RECORD;
  v_count int := 0;
BEGIN
  FOR g IN
    SELECT * FROM public.ludo_games
    WHERE status='open'
      AND ready_deadline IS NOT NULL
      AND now() > ready_deadline
  LOOP
    -- rembourse uniquement les humains (pas les bots), montant = mise du jeu
    FOR p IN
      SELECT user_id
      FROM public.ludo_participants
      WHERE game_id = g.id
        AND user_id IS NOT NULL
        AND COALESCE(is_bot,false) = false
    LOOP
      IF COALESCE(g.stake,0) > 0 THEN
        UPDATE public.profiles
          SET balance_ar = balance_ar + g.stake
          WHERE id = p.user_id;
        INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
          VALUES (p.user_id, 'refund', g.stake, g.id, 'Salle Ludo expirée (non prêts)');
      END IF;
    END LOOP;
    PERFORM public._ludo_purge(g.id);
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END $function$
;

CREATE OR REPLACE FUNCTION public.ludo_quit(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid UUID := auth.uid(); g public.ludo_games%ROWTYPE; st jsonb;
  v_slot INT; v_winner UUID; v_remaining INT;
BEGIN
  SELECT * INTO g FROM public.ludo_games WHERE id=_game_id FOR UPDATE;
  IF g.status NOT IN ('playing','open') THEN RAISE EXCEPTION 'Partie terminée'; END IF;
  SELECT slot INTO v_slot FROM public.ludo_participants WHERE game_id=_game_id AND user_id=v_uid AND is_bot=false;
  IF v_slot IS NULL THEN RAISE EXCEPTION 'Non participant'; END IF;

  IF g.status = 'open' THEN
    UPDATE public.profiles SET balance_ar = balance_ar + g.stake WHERE id=v_uid;
    UPDATE public.ludo_games SET pot = pot - g.stake WHERE id=_game_id;
    INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
      VALUES (v_uid,'refund',g.stake,_game_id,'Annulation avant départ');
    DELETE FROM public.ludo_participants WHERE game_id=_game_id AND user_id=v_uid AND is_bot=false;
    SELECT count(*) INTO v_remaining FROM public.ludo_participants WHERE game_id=_game_id AND is_bot=false;
    IF v_remaining = 0 THEN PERFORM public._ludo_purge(_game_id); END IF;
    RETURN;
  END IF;

  IF g.is_solo THEN
    UPDATE public.ludo_participants SET forfeited=TRUE WHERE game_id=_game_id AND user_id=v_uid AND is_bot=false;
    UPDATE public.ludo_games SET status='finished', finished_at=now() WHERE id=_game_id;
    PERFORM public._ludo_purge(_game_id);
    RETURN;
  END IF;

  UPDATE public.ludo_participants SET forfeited=TRUE WHERE game_id=_game_id AND user_id=v_uid AND is_bot=false;
  st := g.state;
  IF (st->>'turn_slot')::INT = v_slot THEN
    st := jsonb_set(st,'{turn_slot}', to_jsonb(public._ludo_next_slot(_game_id, v_slot, g.max_players)));
    st := jsonb_set(st,'{dice}','null'::jsonb);
    st := jsonb_set(st,'{must_move}','false'::jsonb);
    st := jsonb_set(st,'{turn_started_at}', to_jsonb(to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"')));
    st := jsonb_set(st,'{last_event}', to_jsonb('forfeit'));
    UPDATE public.ludo_games SET state=st, current_turn=(st->>'turn_slot')::INT WHERE id=_game_id;
  END IF;
  v_winner := public._ludo_check_last_standing(_game_id);
  IF v_winner IS NOT NULL THEN
    PERFORM public.finish_game(_game_id, v_winner);
  ELSIF public._ludo_active_humans(_game_id) = 0 THEN
    UPDATE public.ludo_games SET status='finished', finished_at=now() WHERE id=_game_id;
    PERFORM public._ludo_purge(_game_id);
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.ludo_roll(_game_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE st jsonb; g public.ludo_games%ROWTYPE; v_uid UUID := auth.uid();
  v_slot INT; v_user UUID; v_isbot BOOLEAN; v_bias INT; v_dice INT;
  arr jsonb; pawn jsonb; i INT; pstate TEXT; pstep INT; has_move BOOLEAN := FALSE;
  v_consec INT; v_override int; v_now text;
BEGIN
  SELECT * INTO g FROM public.ludo_games WHERE id=_game_id FOR UPDATE;
  IF g.status <> 'playing' THEN RAISE EXCEPTION 'Partie pas en cours'; END IF;
  st := public._ludo_ensure_state(_game_id);
  v_slot := (st->>'turn_slot')::INT;
  SELECT user_id, is_bot, bot_win_bias, consecutive_sixes INTO v_user, v_isbot, v_bias, v_consec
    FROM public.ludo_participants WHERE game_id=_game_id AND slot=v_slot;
  IF NOT v_isbot AND v_user <> v_uid THEN RAISE EXCEPTION 'Pas votre tour'; END IF;
  IF (st->>'must_move')::BOOLEAN THEN RAISE EXCEPTION 'Déjà lancé, déplacez un pion'; END IF;
  v_override := NULLIF(g.dice_override->>v_slot::text,'')::int;
  IF v_override IS NOT NULL AND v_override BETWEEN 1 AND 6 THEN
    v_dice := v_override;
    UPDATE public.ludo_games SET dice_override = dice_override - v_slot::text WHERE id=_game_id;
  ELSE
    v_dice := 1 + (floor(random()*6))::INT;
    IF v_isbot AND COALESCE(v_bias,0) > 0 AND (random()*100) < v_bias THEN v_dice := 6; END IF;
  END IF;
  IF v_dice = 6 THEN v_consec := COALESCE(v_consec,0) + 1; ELSE v_consec := 0; END IF;
  UPDATE public.ludo_participants SET consecutive_sixes=v_consec WHERE game_id=_game_id AND slot=v_slot;
  IF v_consec >= 3 THEN
    UPDATE public.ludo_participants SET consecutive_sixes=0 WHERE game_id=_game_id AND slot=v_slot;
    RETURN public._ludo_advance_turn(_game_id, public._ludo_next_slot(_game_id, v_slot, g.max_players), 'triple_six:cancel');
  END IF;
  arr := st->'pawns'->v_slot::text;
  FOR i IN 0..3 LOOP
    pawn := arr->i; pstate := pawn->>'s'; pstep := (pawn->>'k')::INT;
    IF pstate='finished' THEN CONTINUE; END IF;
    IF pstate='yard' THEN IF v_dice=6 THEN has_move:=TRUE; EXIT; END IF;
    ELSE IF pstep + v_dice <= 56 THEN has_move:=TRUE; EXIT; END IF; END IF;
  END LOOP;
  IF NOT has_move THEN
    UPDATE public.ludo_participants SET consecutive_sixes=0 WHERE game_id=_game_id AND slot=v_slot;
    RETURN public._ludo_advance_turn(_game_id, public._ludo_next_slot(_game_id, v_slot, g.max_players), 'roll:'||v_dice||':no_move');
  END IF;
  v_now := to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"');
  st := jsonb_set(st,'{dice}', to_jsonb(v_dice));
  st := jsonb_set(st,'{must_move}','true'::jsonb);
  st := jsonb_set(st,'{turn_started_at}', to_jsonb(v_now));
  st := jsonb_set(st,'{phase}', to_jsonb('rolled'::text));
  st := jsonb_set(st,'{phase_started_at}', to_jsonb(v_now));
  st := jsonb_set(st,'{last_event}', to_jsonb('roll:'||v_dice));
  UPDATE public.ludo_games SET state=st WHERE id=_game_id;
  RETURN st;
END $function$
;

CREATE OR REPLACE FUNCTION public.ludo_set_auto_move(_game_id uuid, _enabled boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE g public.ludo_games%ROWTYPE;
BEGIN
  SELECT * INTO g FROM public.ludo_games WHERE id = _game_id;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  IF g.host_id <> auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Réservé au créateur de la partie';
  END IF;
  IF g.status <> 'open' THEN RAISE EXCEPTION 'La partie a déjà commencé'; END IF;
  UPDATE public.ludo_games SET auto_move = COALESCE(_enabled, false) WHERE id = _game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.ludo_set_display_name(_game_id uuid, _name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF _name IS NULL OR length(trim(_name)) < 2 THEN RAISE EXCEPTION 'Nom invalide'; END IF;
  UPDATE public.ludo_participants
    SET display_name = trim(_name)
    WHERE game_id=_game_id AND user_id=v_uid;
END $function$
;

CREATE OR REPLACE FUNCTION public.ludo_set_ready(_game_id uuid, _ready boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid UUID := auth.uid(); v_game public.ludo_games%ROWTYPE;
  v_total int; v_ready int; v_verified boolean;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  SELECT phone_verified INTO v_verified FROM public.profiles WHERE id=v_uid;
  IF _ready AND NOT COALESCE(v_verified,false) THEN
    RAISE EXCEPTION 'Vérifiez votre numéro de téléphone dans votre profil';
  END IF;
  SELECT * INTO v_game FROM public.ludo_games WHERE id=_game_id FOR UPDATE;
  IF v_game.id IS NULL OR v_game.status <> 'open' THEN RAISE EXCEPTION 'Partie non ouverte'; END IF;
  UPDATE public.ludo_participants SET ready=_ready, last_seen=now()
    WHERE game_id=_game_id AND user_id=v_uid;
  SELECT count(*), count(*) FILTER (WHERE ready OR is_bot)
    INTO v_total, v_ready
    FROM public.ludo_participants WHERE game_id=_game_id;
  IF v_total = v_game.max_players AND v_ready = v_total THEN
    UPDATE public.ludo_games SET status='playing', started_at=now(),
      state=public._ludo_init_state(v_game.max_players) WHERE id=_game_id;
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.ludo_start_solo_bot(_max_players integer DEFAULT 2, _difficulty text DEFAULT 'medium'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_game_id uuid;
  v_name text;
  v_intel int;
  v_colors4 text[] := ARRAY['red','blue','green','yellow'];
  v_colors3 text[] := ARRAY['red','green','yellow'];
  v_colors2 text[] := ARRAY['red','yellow'];
  v_color text;
  i int;
  v_bot_names text[] := ARRAY['Bot Rina','Bot Naina','Bot Toky','Bot Sanda'];
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF _max_players < 2 OR _max_players > 4 THEN
    RAISE EXCEPTION 'max_players doit être entre 2 et 4';
  END IF;

  v_intel := CASE _difficulty WHEN 'easy' THEN 40 WHEN 'hard' THEN 90 ELSE 70 END;

  INSERT INTO public.ludo_games(host_id, max_players, stake, pot, commission_pct,
                                is_private, mode, status, is_solo)
  VALUES (v_uid, _max_players, 0, 0, 0, TRUE, 'classic', 'open', TRUE)
  RETURNING id INTO v_game_id;

  SELECT COALESCE(NULLIF(trim(pseudo),''),'Joueur') INTO v_name
    FROM public.profiles WHERE id = v_uid;

  -- Humain toujours slot 0 = 'red'
  IF _max_players = 2 THEN v_color := v_colors2[1];
  ELSIF _max_players = 3 THEN v_color := v_colors3[1];
  ELSE v_color := v_colors4[1];
  END IF;

  INSERT INTO public.ludo_participants(game_id, user_id, slot, color, display_name, ready)
  VALUES (v_game_id, v_uid, 0, v_color, COALESCE(v_name,'Joueur'), TRUE);

  FOR i IN 1..(_max_players-1) LOOP
    IF _max_players = 2 THEN v_color := v_colors2[i+1];
    ELSIF _max_players = 3 THEN v_color := v_colors3[i+1];
    ELSE v_color := v_colors4[i+1];
    END IF;
    INSERT INTO public.ludo_participants(
      game_id, user_id, slot, color, is_bot, bot_name, display_name,
      bot_intelligence, bot_win_bias, ready
    ) VALUES (
      v_game_id, NULL, i, v_color, TRUE,
      v_bot_names[i], v_bot_names[i], v_intel, 0, TRUE
    );
  END LOOP;

  RETURN v_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.ludo_tick_all()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g_id uuid;
  st jsonb;
  v_slot int;
  v_isbot boolean;
  v_started timestamptz;
BEGIN
  PERFORM public.ludo_cleanup_empty_rooms();

  FOR g_id IN SELECT id FROM public.ludo_games WHERE status='playing' LOOP
    BEGIN
      PERFORM public.ludo_check_timeout(g_id);
      SELECT state INTO st FROM public.ludo_games WHERE id=g_id;
      IF st IS NULL THEN CONTINUE; END IF;
      v_slot := (st->>'turn_slot')::int;
      SELECT is_bot INTO v_isbot
        FROM public.ludo_participants
       WHERE game_id=g_id AND slot=v_slot;
      IF COALESCE(v_isbot, false) THEN
        v_started := (st->>'turn_started_at')::timestamptz;
        IF v_started IS NULL OR now() - v_started >= interval '3 seconds' THEN
          PERFORM public.ludo_bot_step(g_id);
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION public.mark_messages_read()
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  UPDATE public.admin_user_messages SET read_at = now()
  WHERE user_id = auth.uid() AND from_admin = true AND read_at IS NULL;
$function$
;

CREATE OR REPLACE FUNCTION public.mark_notif_read(_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF _id IS NULL THEN
    UPDATE public.notifications
      SET read = TRUE, read_at = now()
      WHERE user_id = auth.uid() AND read = FALSE;
  ELSE
    UPDATE public.notifications
      SET read = TRUE, read_at = now()
      WHERE id = _id AND user_id = auth.uid();
  END IF;
END; $function$
;

CREATE OR REPLACE FUNCTION public.my_games()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid UUID := auth.uid(); v_result jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  SELECT jsonb_build_object(
    'ongoing', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'id',g.id,'status',g.status,'max_players',g.max_players,'stake',g.stake,'pot',g.pot,
        'room_code',g.room_code,'is_private',g.is_private,'created_at',g.created_at,
        'players_count',(SELECT count(*) FROM public.ludo_participants pp WHERE pp.game_id=g.id))
      ORDER BY g.created_at DESC)
      FROM public.ludo_games g
      JOIN public.ludo_participants p ON p.game_id=g.id
      WHERE p.user_id=v_uid AND g.status IN ('open','playing') AND p.forfeited=false),'[]'::jsonb),
    'finished', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'id',g.id,'status',g.status,'max_players',g.max_players,'stake',g.stake,'pot',g.pot,
        'finished_at',g.finished_at,
        'won', g.winner_id=v_uid,
        'winner_name', (SELECT display_name FROM public.ludo_participants wp WHERE wp.game_id=g.id AND wp.user_id=g.winner_id LIMIT 1),
        'forfeited', p.forfeited)
      ORDER BY g.finished_at DESC NULLS LAST)
      FROM public.ludo_games g
      JOIN public.ludo_participants p ON p.game_id=g.id
      WHERE p.user_id=v_uid AND g.status='finished' LIMIT 50),'[]'::jsonb)
  ) INTO v_result;
  RETURN v_result;
END $function$
;

CREATE OR REPLACE FUNCTION public.my_ongoing_all()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_result jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  SELECT COALESCE(jsonb_agg(row_to_json(t) ORDER BY t.created_at DESC), '[]'::jsonb) INTO v_result FROM (
    SELECT g.id, 'ludo'::text AS game_type, g.status, g.max_players, g.stake, g.pot, g.room_code, g.is_private, g.created_at,
      (SELECT count(*) FROM ludo_participants pp WHERE pp.game_id=g.id) AS players_count
    FROM ludo_games g JOIN ludo_participants p ON p.game_id=g.id
    WHERE p.user_id=v_uid AND g.status IN ('open','playing') AND p.forfeited=false
    UNION ALL
    SELECT g.id, 'domino', g.status, g.max_players, g.stake, g.pot, g.room_code, g.is_private, g.created_at,
      (SELECT count(*) FROM domino_participants pp WHERE pp.game_id=g.id)
    FROM domino_games g JOIN domino_participants p ON p.game_id=g.id
    WHERE p.user_id=v_uid AND g.status IN ('open','playing') AND p.forfeited=false
    UNION ALL
    SELECT g.id, 'fanorona', g.status, 2 AS max_players, g.stake, g.pot, g.room_code, g.is_private, g.created_at,
      (SELECT count(*) FROM fanorona_participants pp WHERE pp.game_id=g.id)
    FROM fanorona_games g JOIN fanorona_participants p ON p.game_id=g.id
    WHERE p.user_id=v_uid AND g.status IN ('open','playing') AND p.forfeited=false
    UNION ALL
    SELECT g.id, 'rami', g.status, g.max_players, g.stake, g.pot, g.room_code, g.is_private, g.created_at,
      (SELECT count(*) FROM rami_participants pp WHERE pp.game_id=g.id)
    FROM rami_games g JOIN rami_participants p ON p.game_id=g.id
    WHERE p.user_id=v_uid AND g.status IN ('open','playing') AND p.forfeited=false
    UNION ALL
    SELECT g.id, 'chess', g.status, 2 AS max_players, g.stake, g.pot, g.room_code, g.is_private, g.created_at,
      (CASE WHEN g.black_id IS NULL THEN 1 ELSE 2 END)::bigint
    FROM chess_games g
    WHERE (g.white_id=v_uid OR g.black_id=v_uid) AND g.status IN ('open','playing')
  ) t;
  RETURN v_result;
END $function$
;

CREATE OR REPLACE FUNCTION public.participant_rename(_game_id uuid, _name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'auth'; END IF;
  UPDATE public.ludo_participants SET display_name=_name WHERE game_id=_game_id AND user_id=auth.uid();
END $function$
;

-- ═══════════ 0007_functions_11.sql ═══════════
-- 0007_functions_11.sql
-- Fonctions et procédures (11/12)

CREATE OR REPLACE FUNCTION public.petanque_add_bot(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  g public.petanque_games%ROWTYPE;
  v_count INT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  SELECT * INTO g FROM public.petanque_games WHERE id=_game_id FOR UPDATE;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  IF g.status <> 'open' THEN RAISE EXCEPTION 'Partie déjà commencée'; END IF;
  IF g.stake > 0 AND NOT public.has_role(v_uid, 'admin') THEN
    RAISE EXCEPTION 'Bots réservés à l''admin pour les parties avec mise';
  END IF;
  IF g.creator_id <> v_uid AND NOT public.has_role(v_uid, 'admin') THEN
    RAISE EXCEPTION 'Seul le créateur peut ajouter un bot';
  END IF;
  SELECT count(*) INTO v_count FROM public.petanque_participants WHERE game_id=_game_id;
  IF v_count >= 2 THEN RAISE EXCEPTION 'Partie complète'; END IF;
  INSERT INTO public.petanque_participants(game_id, user_id, team, seat, boules_left, is_bot, ready)
    VALUES (_game_id, NULL, 1, 1, 3, true, true);
END $function$
;

CREATE OR REPLACE FUNCTION public.petanque_bot_step(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g public.petanque_games%ROWTYPE;
  p public.petanque_participants%ROWTYPE;
  v_throw_y DOUBLE PRECISION;
  v_dx DOUBLE PRECISION;
  v_dy DOUBLE PRECISION;
  v_angle DOUBLE PRECISION;
  v_power DOUBLE PRECISION;
  v_noise DOUBLE PRECISION;
  v_order INT;
  sim RECORD;
  v_next UUID;
  v_boules_left_total INT;
BEGIN
  SELECT * INTO g FROM public.petanque_games WHERE id=_game_id FOR UPDATE;
  IF g.status <> 'playing' THEN RETURN; END IF;
  SELECT * INTO p FROM public.petanque_participants
    WHERE game_id=_game_id AND user_id IS NULL AND is_bot=true AND boules_left > 0
    ORDER BY seat LIMIT 1;
  IF p.id IS NULL THEN RETURN; END IF;
  -- Si le tour n'est pas au bot (donc current_player_id est un humain), rien à faire
  IF g.current_player_id IS NOT NULL THEN RETURN; END IF;

  v_throw_y := CASE WHEN p.team=0 THEN -0.25 ELSE 0.25 END;
  v_dx := g.cochonnet_x - (-0.9);
  v_dy := g.cochonnet_y - v_throw_y;
  v_angle := atan2(v_dy, v_dx);
  v_noise := (random() - 0.5) * 0.08; -- bruit sur angle
  v_angle := v_angle + v_noise;
  -- Distance visée -> power
  v_power := LEAST(1.0, GREATEST(0.2, sqrt(v_dx*v_dx + v_dy*v_dy) / 1.7 + (random()-0.5)*0.06));

  SELECT COALESCE(max(play_order),0)+1 INTO v_order FROM public.petanque_boules
    WHERE game_id=_game_id AND round=g.current_round;
  SELECT * INTO sim FROM public._petanque_simulate(v_throw_y, v_angle, v_power, 0, 0.5);

  INSERT INTO public.petanque_boules(game_id, round, team, player_id, play_order, x, y, dead, distance, angle, power, spin, lob)
    VALUES (_game_id, g.current_round, p.team, NULL, v_order,
            sim.final_x, sim.final_y, sim.dead,
            public._petanque_distance(sim.final_x, sim.final_y, g.cochonnet_x, g.cochonnet_y),
            v_angle, v_power, 0, 0.5);

  UPDATE public.petanque_participants SET boules_left = boules_left - 1 WHERE id=p.id;

  SELECT COALESCE(sum(boules_left),0) INTO v_boules_left_total FROM public.petanque_participants WHERE game_id=_game_id;
  IF v_boules_left_total = 0 THEN
    PERFORM public._petanque_end_round(_game_id);
    RETURN;
  END IF;
  v_next := public._petanque_next_player(_game_id);
  UPDATE public.petanque_games
    SET current_player_id = v_next, turn_deadline = now() + interval '30 seconds'
    WHERE id=_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.petanque_create(p_stake numeric DEFAULT 0, p_public boolean DEFAULT true)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_bal NUMERIC;
  v_id  UUID;
  v_code TEXT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  IF p_stake < 0 THEN RAISE EXCEPTION 'invalid stake'; END IF;
  IF p_stake > 0 THEN
    SELECT balance_ar INTO v_bal FROM public.profiles WHERE id = v_uid FOR UPDATE;
    IF v_bal IS NULL OR v_bal < p_stake THEN RAISE EXCEPTION 'insufficient balance'; END IF;
    UPDATE public.profiles SET balance_ar = balance_ar - p_stake WHERE id = v_uid;
    INSERT INTO public.transactions(user_id, type, amount, note)
      VALUES (v_uid, 'stake', -p_stake, 'Mise pétanque');
  END IF;
  IF NOT p_public THEN
    v_code := upper(substring(md5(random()::text || clock_timestamp()::text) FROM 1 FOR 6));
  END IF;
  INSERT INTO public.petanque_games (creator_id, stake, pot, is_private, room_code)
    VALUES (v_uid, p_stake, p_stake, NOT p_public, v_code)
    RETURNING id INTO v_id;
  INSERT INTO public.petanque_participants (game_id, user_id, team, seat, boules_left, ready)
    VALUES (v_id, v_uid, 0, 0, 3, false);
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.petanque_join(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  g public.petanque_games%ROWTYPE;
  v_bal NUMERIC;
  v_count INT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  SELECT * INTO g FROM public.petanque_games WHERE id = _game_id FOR UPDATE;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  IF g.status <> 'open' THEN RAISE EXCEPTION 'Partie non disponible'; END IF;
  IF EXISTS (SELECT 1 FROM public.petanque_participants WHERE game_id=_game_id AND user_id=v_uid) THEN
    RETURN;
  END IF;
  SELECT count(*) INTO v_count FROM public.petanque_participants WHERE game_id=_game_id;
  IF v_count >= 2 THEN RAISE EXCEPTION 'Partie complète'; END IF;
  IF g.stake > 0 THEN
    SELECT balance_ar INTO v_bal FROM public.profiles WHERE id=v_uid FOR UPDATE;
    IF v_bal IS NULL OR v_bal < g.stake THEN RAISE EXCEPTION 'insufficient balance'; END IF;
    UPDATE public.profiles SET balance_ar = balance_ar - g.stake WHERE id=v_uid;
    INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
      VALUES (v_uid, 'stake', -g.stake, _game_id, 'Mise pétanque');
    UPDATE public.petanque_games SET pot = pot + g.stake WHERE id=_game_id;
  END IF;
  INSERT INTO public.petanque_participants (game_id, user_id, team, seat, boules_left)
    VALUES (_game_id, v_uid, 1, 1, 3);
END $function$
;

CREATE OR REPLACE FUNCTION public.petanque_join_code(_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_id UUID;
BEGIN
  SELECT id INTO v_id FROM public.petanque_games WHERE room_code = upper(_code) AND status='open';
  IF v_id IS NULL THEN RAISE EXCEPTION 'Code invalide'; END IF;
  PERFORM public.petanque_join(v_id);
  RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.petanque_leave(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  g public.petanque_games%ROWTYPE;
  p public.petanque_participants%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  SELECT * INTO g FROM public.petanque_games WHERE id=_game_id FOR UPDATE;
  IF g.id IS NULL THEN RETURN; END IF;
  SELECT * INTO p FROM public.petanque_participants WHERE game_id=_game_id AND user_id=v_uid;
  IF p.id IS NULL THEN RETURN; END IF;
  IF g.status = 'open' THEN
    -- Remboursement
    IF g.stake > 0 THEN
      UPDATE public.profiles SET balance_ar = balance_ar + g.stake WHERE id=v_uid;
      INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
        VALUES (v_uid,'refund',g.stake,_game_id,'Départ salle d''attente pétanque');
      UPDATE public.petanque_games SET pot = pot - g.stake WHERE id=_game_id;
    END IF;
    DELETE FROM public.petanque_participants WHERE id=p.id;
    -- Si plus personne : supprimer la partie
    IF NOT EXISTS (SELECT 1 FROM public.petanque_participants WHERE game_id=_game_id) THEN
      DELETE FROM public.petanque_games WHERE id=_game_id;
    END IF;
  ELSIF g.status = 'playing' THEN
    -- Forfait : adversaire gagne
    UPDATE public.petanque_games
      SET status='finished', finished_at=now(),
          winner_team = CASE WHEN p.team=0 THEN 1 ELSE 0 END
      WHERE id=_game_id;
    PERFORM public._petanque_settle(_game_id);
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.petanque_set_ready(_game_id uuid, _ready boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  g public.petanque_games%ROWTYPE;
  v_ready_count INT;
  v_total INT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  UPDATE public.petanque_participants SET ready=_ready
    WHERE game_id=_game_id AND user_id=v_uid;
  SELECT * INTO g FROM public.petanque_games WHERE id=_game_id FOR UPDATE;
  IF g.status <> 'open' THEN RETURN; END IF;
  SELECT count(*) INTO v_total FROM public.petanque_participants WHERE game_id=_game_id;
  SELECT count(*) INTO v_ready_count FROM public.petanque_participants WHERE game_id=_game_id AND ready=true;
  IF v_total >= 2 AND v_ready_count = v_total THEN
    -- Démarrer : équipe 0 commence
    UPDATE public.petanque_games
      SET status='playing', started_at=now(),
          current_player_id = (SELECT user_id FROM public.petanque_participants WHERE game_id=_game_id AND team=0 ORDER BY seat LIMIT 1),
          turn_deadline = now() + interval '30 seconds'
      WHERE id=_game_id;
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.petanque_throw(_game_id uuid, _angle double precision, _power double precision, _spin double precision, _lob double precision)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  g public.petanque_games%ROWTYPE;
  p public.petanque_participants%ROWTYPE;
  v_throw_y DOUBLE PRECISION;
  v_order INT;
  sim RECORD;
  b RECORD;
  v_next UUID;
  v_boules_left_total INT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  SELECT * INTO g FROM public.petanque_games WHERE id=_game_id FOR UPDATE;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  IF g.status <> 'playing' THEN RAISE EXCEPTION 'Partie non en cours'; END IF;
  IF g.current_player_id <> v_uid THEN RAISE EXCEPTION 'Ce n''est pas votre tour'; END IF;
  SELECT * INTO p FROM public.petanque_participants WHERE game_id=_game_id AND user_id=v_uid;
  IF p.id IS NULL OR p.boules_left <= 0 THEN RAISE EXCEPTION 'Aucune boule restante'; END IF;

  v_throw_y := CASE WHEN p.team=0 THEN -0.25 ELSE 0.25 END;
  SELECT COALESCE(max(play_order),0)+1 INTO v_order FROM public.petanque_boules
    WHERE game_id=_game_id AND round=g.current_round;

  SELECT * INTO sim FROM public._petanque_simulate(v_throw_y, _angle, _power, _spin, _lob);

  INSERT INTO public.petanque_boules(game_id, round, team, player_id, play_order, x, y, dead, distance, angle, power, spin, lob)
    VALUES (_game_id, g.current_round, p.team, v_uid, v_order,
            sim.final_x, sim.final_y, sim.dead,
            public._petanque_distance(sim.final_x, sim.final_y, g.cochonnet_x, g.cochonnet_y),
            _angle, _power, _spin, _lob);

  -- Collisions simples : déplace la boule statique la plus proche si impact
  FOR b IN
    SELECT * FROM public.petanque_boules
      WHERE game_id=_game_id AND round=g.current_round AND dead=false AND play_order < v_order
        AND public._petanque_distance(x, y, sim.final_x, sim.final_y) < 0.08
      ORDER BY public._petanque_distance(x, y, sim.final_x, sim.final_y) ASC
      LIMIT 1
  LOOP
    DECLARE
      dx DOUBLE PRECISION := b.x - sim.final_x;
      dy DOUBLE PRECISION := b.y - sim.final_y;
      dist DOUBLE PRECISION := sqrt(dx*dx + dy*dy);
      push DOUBLE PRECISION := (0.08 - dist) + 0.1 * _power;
      nx DOUBLE PRECISION;
      ny DOUBLE PRECISION;
      is_dead BOOLEAN;
    BEGIN
      IF dist < 0.001 THEN dx := 0.01; dy := 0.0; dist := 0.01; END IF;
      nx := b.x + (dx/dist) * push;
      ny := b.y + (dy/dist) * push;
      is_dead := nx > 1.0 OR nx < -1.0 OR ny > 0.45 OR ny < -0.45;
      UPDATE public.petanque_boules
        SET x=nx, y=ny, dead=is_dead,
            distance = public._petanque_distance(nx, ny, g.cochonnet_x, g.cochonnet_y)
        WHERE id=b.id;
    END;
  END LOOP;

  UPDATE public.petanque_participants SET boules_left = boules_left - 1 WHERE id=p.id;

  -- Fin de mène ?
  SELECT COALESCE(sum(boules_left),0) INTO v_boules_left_total FROM public.petanque_participants WHERE game_id=_game_id;
  IF v_boules_left_total = 0 THEN
    PERFORM public._petanque_end_round(_game_id);
    RETURN jsonb_build_object('final_x', sim.final_x, 'final_y', sim.final_y, 'dead', sim.dead, 'round_end', true);
  END IF;

  v_next := public._petanque_next_player(_game_id);
  UPDATE public.petanque_games
    SET current_player_id = v_next, turn_deadline = now() + interval '30 seconds'
    WHERE id=_game_id;

  RETURN jsonb_build_object('final_x', sim.final_x, 'final_y', sim.final_y, 'dead', sim.dead, 'round_end', false);
END $function$
;

CREATE OR REPLACE FUNCTION public.player_add_bot(_game_id uuid, _bot_name text DEFAULT 'Bot'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g public.ludo_games%ROWTYPE;
  v_slot int;
  v_colors4 text[] := ARRAY['red','blue','green','yellow'];
  v_colors2 text[] := ARRAY['red','yellow'];
  v_colors3 text[] := ARRAY['red','green','yellow'];
  v_color text;
  v_count int;
  v_uid uuid := auth.uid();
  v_is_admin boolean := public.is_admin();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Connexion requise'; END IF;
  SELECT * INTO g FROM public.ludo_games WHERE id=_game_id FOR UPDATE;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  IF g.status <> 'open' THEN RAISE EXCEPTION 'La partie a déjà commencé'; END IF;

  IF NOT v_is_admin THEN
    IF COALESCE(g.stake,0) > 0 THEN
      RAISE EXCEPTION 'Bots réservés aux parties gratuites';
    END IF;
    IF g.host_id <> v_uid
       AND NOT EXISTS (SELECT 1 FROM public.ludo_participants WHERE game_id=_game_id AND user_id=v_uid) THEN
      RAISE EXCEPTION 'Vous devez rejoindre la partie pour ajouter un bot';
    END IF;
  END IF;

  SELECT count(*) INTO v_count FROM public.ludo_participants WHERE game_id=_game_id;
  IF v_count >= g.max_players THEN RAISE EXCEPTION 'Partie pleine'; END IF;

  SELECT s INTO v_slot
    FROM generate_series(0, g.max_players-1) AS s
   WHERE s NOT IN (SELECT slot FROM public.ludo_participants WHERE game_id=_game_id)
   ORDER BY s LIMIT 1;

  IF g.max_players = 2 THEN v_color := v_colors2[v_slot+1];
  ELSIF g.max_players = 3 THEN v_color := v_colors3[v_slot+1];
  ELSE v_color := v_colors4[v_slot+1];
  END IF;

  INSERT INTO public.ludo_participants(
    game_id, user_id, slot, color, is_bot, bot_name, display_name,
    bot_intelligence, bot_win_bias, ready
  ) VALUES (
    _game_id, NULL, v_slot, v_color, TRUE,
    COALESCE(NULLIF(trim(_bot_name),''),'Bot'),
    COALESCE(NULLIF(trim(_bot_name),''),'Bot'),
    70, 0, TRUE
  );
END $function$
;

CREATE OR REPLACE FUNCTION public.player_submit_claim(_tournament_id uuid, _match_id uuid, _category text, _description text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_reason text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  IF _description IS NULL OR length(trim(_description)) < 10 THEN
    RAISE EXCEPTION 'Description trop courte';
  END IF;

  IF _match_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.tournament_matches
    WHERE id = _match_id AND auth.uid() = ANY(player_ids)
  ) THEN
    RAISE EXCEPTION 'Vous n''êtes pas participant à ce match';
  END IF;

  v_reason := '[' || COALESCE(NULLIF(_category,''), 'autre') || '] ' || trim(_description);

  INSERT INTO public.tournament_claims(tournament_id, match_id, claimant_id, reason, status)
    VALUES (_tournament_id, _match_id, auth.uid(), v_reason, 'pending')
    RETURNING id INTO v_id;

  -- Notifier les admins
  BEGIN
    INSERT INTO public.notifications(user_id, kind, title, body, link, ref_id)
    SELECT ur.user_id, 'tournament',
           'Nouvelle réclamation',
           'Catégorie: ' || COALESCE(_category,'autre'),
           '/admin', v_id
    FROM public.user_roles ur WHERE ur.role = 'admin';
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN v_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.poker_action(_game_id uuid, _action text, _amount numeric DEFAULT 0)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  g public.poker_games%ROWTYPE;
  me public.poker_players%ROWTYPE;
  cur_bet numeric; call_amount numeric; next_seat int; next_user uuid;
  n_active int;
BEGIN
  SELECT * INTO g FROM public.poker_games WHERE id=_game_id FOR UPDATE;
  IF g.status != 'playing' THEN RAISE EXCEPTION 'Partie non active'; END IF;
  IF g.current_player != v_uid THEN RAISE EXCEPTION 'Ce n''est pas votre tour'; END IF;
  SELECT * INTO me FROM public.poker_players WHERE game_id=_game_id AND user_id=v_uid;
  cur_bet := (g.state->>'current_bet')::numeric;
  call_amount := GREATEST(cur_bet - me.bet_round, 0);

  CASE _action
    WHEN 'fold' THEN
      UPDATE public.poker_players SET status='folded', last_action='fold' WHERE game_id=_game_id AND user_id=v_uid;
    WHEN 'check' THEN
      IF call_amount > 0 THEN RAISE EXCEPTION 'Vous devez suivre ou passer'; END IF;
      UPDATE public.poker_players SET last_action='check' WHERE game_id=_game_id AND user_id=v_uid;
    WHEN 'call' THEN
      DECLARE actual numeric := LEAST(call_amount, me.chips);
      BEGIN
        UPDATE public.poker_players SET chips=chips-actual, bet_round=bet_round+actual, last_action='call'
          WHERE game_id=_game_id AND user_id=v_uid;
        UPDATE public.poker_games SET pot=pot+actual, updated_at=now() WHERE id=_game_id;
        IF me.chips - actual <= 0 THEN
          UPDATE public.poker_players SET status='all_in' WHERE game_id=_game_id AND user_id=v_uid;
        END IF;
      END;
    WHEN 'raise', 'bet' THEN
      IF _amount <= cur_bet THEN RAISE EXCEPTION 'Relance insuffisante'; END IF;
      IF _amount > me.chips + me.bet_round THEN RAISE EXCEPTION 'Jetons insuffisants'; END IF;
      DECLARE add_chips numeric := _amount - me.bet_round;
      BEGIN
        UPDATE public.poker_players SET chips=chips-add_chips, bet_round=_amount, last_action=_action
          WHERE game_id=_game_id AND user_id=v_uid;
        UPDATE public.poker_games SET
          pot=pot+add_chips,
          state=state||jsonb_build_object('current_bet',_amount,'last_raise',_amount-cur_bet),
          updated_at=now()
        WHERE id=_game_id;
        IF me.chips - add_chips <= 0 THEN
          UPDATE public.poker_players SET status='all_in' WHERE game_id=_game_id AND user_id=v_uid;
        END IF;
        UPDATE public.poker_players SET last_action=NULL
          WHERE game_id=_game_id AND user_id!=v_uid AND status='playing';
      END;
    WHEN 'allin' THEN
      DECLARE all_chips numeric := me.chips;
      DECLARE new_total numeric := me.bet_round + all_chips;
      BEGIN
        UPDATE public.poker_players SET chips=0, bet_round=new_total, status='all_in', last_action='allin'
          WHERE game_id=_game_id AND user_id=v_uid;
        UPDATE public.poker_games SET pot=pot+all_chips, updated_at=now() WHERE id=_game_id;
        IF new_total > cur_bet THEN
          UPDATE public.poker_games SET state=state||jsonb_build_object('current_bet',new_total) WHERE id=_game_id;
          UPDATE public.poker_players SET last_action=NULL
            WHERE game_id=_game_id AND user_id!=v_uid AND status='playing';
        END IF;
      END;
    ELSE RAISE EXCEPTION 'Action inconnue: %', _action;
  END CASE;

  SELECT * INTO g FROM public.poker_games WHERE id=_game_id;
  SELECT count(*) INTO n_active FROM public.poker_players WHERE game_id=_game_id AND status='playing';

  IF n_active <= 1 OR public._poker_round_done(_game_id) THEN
    PERFORM public._poker_next_street(_game_id);
  ELSE
    next_seat := public._poker_next_player(_game_id, me.seat);
    SELECT user_id INTO next_user FROM public.poker_players WHERE game_id=_game_id AND seat=next_seat;
    UPDATE public.poker_games SET current_player=next_user, turn_deadline=now()+interval '30 seconds', updated_at=now() WHERE id=_game_id;
  END IF;

  -- Autoplay des bots consécutifs
  PERFORM public.poker_autoplay_bots(_game_id);
END $function$
;

CREATE OR REPLACE FUNCTION public.poker_add_bot(_game_id uuid, _bot_name text DEFAULT 'Bot'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_is_admin boolean := public.is_admin();
  g public.poker_games%ROWTYPE;
  v_count int; v_seat int; v_name text;
  v_bot_names text[] := ARRAY['Bot Rija','Bot Naina','Bot Hery','Bot Voara','Bot Tojo','Bot Fara'];
  v_bot_uid uuid := gen_random_uuid();
  v_start_chips numeric := 10000;
  v_all_ready boolean;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Connexion requise'; END IF;
  SELECT * INTO g FROM public.poker_games WHERE id=_game_id FOR UPDATE;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  IF g.status <> 'waiting' THEN RAISE EXCEPTION 'La partie a déjà commencé'; END IF;

  IF NOT v_is_admin THEN
    IF COALESCE(g.stake,0) > 0 THEN RAISE EXCEPTION 'Bots réservés aux parties gratuites'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.poker_players WHERE game_id=_game_id AND user_id=v_uid) THEN
      RAISE EXCEPTION 'Rejoignez la partie pour ajouter un bot';
    END IF;
  END IF;

  SELECT count(*) INTO v_count FROM public.poker_players WHERE game_id=_game_id;
  IF v_count >= g.max_players THEN RAISE EXCEPTION 'Partie pleine'; END IF;

  SELECT s INTO v_seat FROM generate_series(0, g.max_players-1) s
    WHERE s NOT IN (SELECT seat FROM public.poker_players WHERE game_id=_game_id)
    ORDER BY s LIMIT 1;

  v_name := COALESCE(NULLIF(trim(_bot_name),''), v_bot_names[LEAST(v_seat+1, array_length(v_bot_names,1))]);

  INSERT INTO public.poker_players(game_id, user_id, seat, chips, status, is_ready, is_bot, bot_name, bot_intelligence)
    VALUES (_game_id, v_bot_uid, v_seat, v_start_chips, 'waiting', TRUE, TRUE, v_name, 70);

  SELECT bool_and(is_ready) INTO v_all_ready FROM public.poker_players WHERE game_id=_game_id;
  IF COALESCE(v_all_ready,false) AND (v_count+1) >= 2 THEN
    UPDATE public.poker_games SET status='playing', started_at=now(), updated_at=now() WHERE id=_game_id;
    UPDATE public.poker_players SET status='playing' WHERE game_id=_game_id;
    PERFORM public._poker_deal_hand(_game_id);
    PERFORM public.poker_autoplay_bots(_game_id);
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.poker_autoplay_bots(_game_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  played int := 0; guard int := 0; ok boolean;
BEGIN
  LOOP
    guard := guard + 1;
    IF guard > 50 THEN EXIT; END IF;
    ok := public._poker_bot_act(_game_id);
    IF NOT ok THEN EXIT; END IF;
    played := played + 1;
  END LOOP;
  RETURN played;
END $function$
;

CREATE OR REPLACE FUNCTION public.poker_join(_game_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  g public.poker_games%ROWTYPE;
  v_balance numeric;
  v_count int;
  v_seat int;
  v_chips numeric := 10000;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Connexion requise'; END IF;
  SELECT * INTO g FROM public.poker_games WHERE id = _game_id FOR UPDATE;
  IF g.id IS NULL THEN RAISE EXCEPTION 'Partie introuvable'; END IF;
  IF g.status <> 'waiting' AND g.status <> 'open' THEN RAISE EXCEPTION 'Partie non disponible'; END IF;

  IF EXISTS(SELECT 1 FROM public.poker_players WHERE game_id = _game_id AND user_id = v_uid) THEN
    RETURN _game_id;
  END IF;

  SELECT count(*) INTO v_count FROM public.poker_players WHERE game_id = _game_id;
  IF v_count >= g.max_players THEN RAISE EXCEPTION 'Table pleine'; END IF;

  IF COALESCE(g.stake,0) > 0 THEN
    SELECT balance_ar INTO v_balance FROM public.profiles WHERE id = v_uid FOR UPDATE;
    IF COALESCE(v_balance,0) < g.stake THEN RAISE EXCEPTION 'Solde insuffisant'; END IF;
    UPDATE public.profiles SET balance_ar = balance_ar - g.stake WHERE id = v_uid;
    INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
      VALUES (v_uid, 'poker_stake', -g.stake, _game_id, 'Rejoindre table poker');
    UPDATE public.poker_games SET pot = pot + g.stake WHERE id = _game_id;
  END IF;

  SELECT s INTO v_seat FROM generate_series(0, g.max_players-1) s
    WHERE s NOT IN (SELECT seat FROM public.poker_players WHERE game_id = _game_id)
    ORDER BY s LIMIT 1;

  INSERT INTO public.poker_players(game_id, user_id, seat, chips, status, is_ready, is_bot)
    VALUES (_game_id, v_uid, v_seat, v_chips, 'waiting', FALSE, FALSE);

  RETURN _game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.poker_my_hole_cards(_game_id uuid)
 RETURNS TABLE(user_id uuid, hole_cards integer[])
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT pp.user_id, pp.hole_cards
    FROM public.poker_players pp
   WHERE pp.game_id = _game_id
     AND (pp.user_id = auth.uid()
          OR public.is_admin()
          OR EXISTS (SELECT 1 FROM public.poker_games g WHERE g.id = _game_id AND g.status = 'finished'));
$function$
;

CREATE OR REPLACE FUNCTION public.poker_set_ready(_game_id uuid, _ready boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  g public.poker_games%ROWTYPE;
  all_ready boolean;
  player_cnt int;
BEGIN
  SELECT * INTO g FROM public.poker_games WHERE id=_game_id FOR UPDATE;
  IF g.status != 'waiting' THEN RAISE EXCEPTION 'Partie déjà commencée'; END IF;
  UPDATE public.poker_players SET is_ready=_ready WHERE game_id=_game_id AND user_id=v_uid;
  SELECT count(*), bool_and(is_ready) INTO player_cnt, all_ready
    FROM public.poker_players WHERE game_id=_game_id;
  IF all_ready AND player_cnt >= 2 THEN
    UPDATE public.poker_games SET status='playing', started_at=now(), updated_at=now() WHERE id=_game_id;
    UPDATE public.poker_players SET status='playing' WHERE game_id=_game_id;
    PERFORM public._poker_deal_hand(_game_id);
    PERFORM public.poker_autoplay_bots(_game_id);
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.poker_start_next_hand(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.has_role(auth.uid(),'admin') THEN
    IF auth.uid() NOT IN (SELECT user_id FROM public.poker_players WHERE game_id=_game_id AND is_bot=false LIMIT 1) THEN
      RAISE EXCEPTION 'Accès refusé';
    END IF;
  END IF;
  UPDATE public.poker_games SET phase='preflop', pot=0, community_cards='{}', updated_at=now()
    WHERE id=_game_id AND phase='between_hands';
  PERFORM public._poker_deal_hand(_game_id);
  PERFORM public.poker_autoplay_bots(_game_id);
END $function$
;

CREATE OR REPLACE FUNCTION public.poker_start_solo_bot(_max_players integer DEFAULT 3, _difficulty text DEFAULT 'medium'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_name text;
  v_intel int;
  v_paused boolean;
  v_banned boolean;
  v_gid uuid;
  v_code text;
  v_slot int;
  v_bot_names text[] := ARRAY['Bot Rija','Bot Naina','Bot Hery','Bot Voara','Bot Tojo','Bot Fara','Bot Zoky','Bot Mialy'];
  v_bot_uid uuid;
  v_start_chips numeric := 10000;
BEGIN
  PERFORM public._assert_solo_bot_enabled();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF _max_players NOT BETWEEN 2 AND 6 THEN RAISE EXCEPTION 'Joueurs invalides (2-6)'; END IF;

  SELECT paused INTO v_paused FROM public.app_settings WHERE id=1;
  IF COALESCE(v_paused,false) THEN RAISE EXCEPTION 'Application en pause'; END IF;

  SELECT banned, pseudo INTO v_banned, v_name FROM public.profiles WHERE id=v_uid;
  IF COALESCE(v_banned,false) THEN RAISE EXCEPTION 'Compte banni'; END IF;

  CASE lower(_difficulty)
    WHEN 'easy'   THEN v_intel := 30;
    WHEN 'hard'   THEN v_intel := 95;
    ELSE               v_intel := 70;
  END CASE;

  v_code := public._gen_room_code();

  INSERT INTO public.poker_games(
    status, stake, commission_pct, max_players, is_private, room_code,
    created_by, phase, started_at
  ) VALUES (
    'playing', 0, 0, _max_players, true, v_code,
    v_uid, 'waiting', now()
  ) RETURNING id INTO v_gid;

  -- Humain siège 0
  INSERT INTO public.poker_players(game_id, user_id, seat, chips, status, is_ready, is_bot)
    VALUES (v_gid, v_uid, 0, v_start_chips, 'playing', true, false);

  -- Bots
  FOR v_slot IN 1.._max_players - 1 LOOP
    v_bot_uid := gen_random_uuid();
    INSERT INTO public.poker_players(
      game_id, user_id, seat, chips, status, is_ready,
      is_bot, bot_name, bot_intelligence
    ) VALUES (
      v_gid, v_bot_uid, v_slot, v_start_chips, 'playing', true,
      true, v_bot_names[v_slot], v_intel
    );
  END LOOP;

  -- Distribue la première main puis autoplay si un bot commence
  PERFORM public._poker_deal_hand(v_gid);
  PERFORM public.poker_autoplay_bots(v_gid);

  RETURN v_gid;
END $function$
;

CREATE OR REPLACE FUNCTION public.rami_add_bot(_game_id uuid, _bot_name text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  g public.rami_games;
  v_is_admin boolean;
  v_slot int;
  v_count int;
  v_name text;
  v_bot_names text[] := ARRAY['Bot Rija','Bot Naina','Bot Hery','Bot Voara','Bot Miora','Bot Tahina'];
  v_intel int := 70;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO g FROM public.rami_games WHERE id = _game_id FOR UPDATE;
  IF g.id IS NULL THEN RAISE EXCEPTION 'partie introuvable'; END IF;
  IF g.status <> 'waiting' THEN RAISE EXCEPTION 'partie déjà commencée'; END IF;

  v_is_admin := public.has_role(v_uid, 'admin'::app_role);
  IF NOT v_is_admin AND g.created_by <> v_uid THEN
    RAISE EXCEPTION 'seul l''hôte peut ajouter un bot';
  END IF;
  IF NOT v_is_admin AND g.stake > 0 THEN
    RAISE EXCEPTION 'les bots ne sont autorisés qu''en partie gratuite';
  END IF;

  SELECT count(*) INTO v_count FROM public.rami_participants WHERE game_id = _game_id;
  IF v_count >= g.max_players THEN RAISE EXCEPTION 'partie pleine'; END IF;

  -- first free slot
  SELECT s.slot INTO v_slot
  FROM generate_series(0, g.max_players - 1) s(slot)
  WHERE s.slot NOT IN (SELECT slot FROM public.rami_participants WHERE game_id = _game_id)
  ORDER BY s.slot LIMIT 1;

  v_name := COALESCE(NULLIF(_bot_name,''), v_bot_names[1 + (v_slot % array_length(v_bot_names,1))]);

  INSERT INTO public.rami_participants(
    game_id, user_id, slot, display_name, ready, is_bot, bot_name, bot_intelligence, hand_count
  ) VALUES (
    _game_id, NULL, v_slot, v_name, true, true, v_name, v_intel, 0
  );

  -- Auto-start if now full and all humans ready
  IF (SELECT count(*) FROM public.rami_participants WHERE game_id = _game_id) = g.max_players
     AND (SELECT count(*) FROM public.rami_participants WHERE game_id = _game_id AND NOT ready) = 0 THEN
    PERFORM public.rami_start(_game_id);
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.rami_create(_stake numeric, _max integer, _private boolean, _commission integer, _joker_mode text DEFAULT 'classique'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE _uid uuid := auth.uid(); _id uuid; _code text; _bal numeric; _name text; _mode text;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  IF _max < 2 OR _max > 4 THEN RAISE EXCEPTION 'players 2-4'; END IF;
  IF _stake < 0 THEN RAISE EXCEPTION 'stake invalid'; END IF;
  _mode := COALESCE(_joker_mode,'classique');
  IF _mode NOT IN ('sans','aleatoire','classique','double') THEN
    RAISE EXCEPTION 'mode joker invalide';
  END IF;

  SELECT balance_ar, COALESCE(pseudo,'Joueur') INTO _bal,_name
    FROM public.profiles WHERE id=_uid FOR UPDATE;
  IF _bal IS NULL OR _bal < _stake THEN RAISE EXCEPTION 'solde insuffisant'; END IF;
  _code := public._rami_gen_code();

  INSERT INTO public.rami_games (room_code,is_private,stake,max_players,commission_pct,created_by,pot,joker_mode)
  VALUES (_code,COALESCE(_private,true),_stake,_max,COALESCE(_commission,10),_uid,_stake,_mode)
  RETURNING id INTO _id;

  IF _stake > 0 THEN
    UPDATE public.profiles SET balance_ar=balance_ar-_stake WHERE id=_uid;
    INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
    VALUES (_uid,'rami_stake',-_stake,_id,'Create rami');
  END IF;

  INSERT INTO public.rami_participants(game_id,user_id,slot,display_name)
  VALUES (_id,_uid,0,_name);

  RETURN _id;
END $function$
;

CREATE OR REPLACE FUNCTION public.rami_discard(_game_id uuid, _card integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE _uid uuid := auth.uid(); _g public.rami_games; _slot int; _state jsonb;
  _hand int[]; _new_hand int[]; _discard int[]; _hands jsonb;
  _parts int[]; _next int; _cfg record;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO _g FROM public.rami_games WHERE id=_game_id FOR UPDATE;
  IF _g.status <> 'playing' THEN RAISE EXCEPTION 'partie inactive'; END IF;
  SELECT slot INTO _slot FROM public.rami_participants WHERE game_id=_game_id AND user_id=_uid;
  IF _slot IS NULL THEN RAISE EXCEPTION 'non participant'; END IF;
  IF _slot <> _g.current_turn OR _g.turn_phase <> 'play' THEN RAISE EXCEPTION 'pas ton tour'; END IF;

  SELECT * INTO _cfg FROM public._game_cfg('rami');

  _state := _g.state;
  _hand := ARRAY(SELECT jsonb_array_elements_text(_state->'hands'->_uid::text))::int[];
  IF NOT (_card = ANY(_hand)) THEN RAISE EXCEPTION 'carte absente'; END IF;
  _new_hand := public._rami_remove_one(_hand,_card);
  _discard := ARRAY(SELECT jsonb_array_elements_text(_state->'discard'))::int[];
  _discard := array_append(_discard,_card);
  _hands := jsonb_set(_state->'hands', ARRAY[_uid::text], to_jsonb(_new_hand));
  _state := jsonb_set(_state,'{hands}',_hands);
  _state := jsonb_set(_state,'{discard}',to_jsonb(_discard));

  UPDATE public.rami_participants
     SET hand_count=COALESCE(array_length(_new_hand,1),0)
   WHERE game_id=_game_id AND user_id=_uid;

  -- Plus de détection auto de victoire : le joueur doit cliquer sur « Valider ma main ».

  SELECT array_agg(slot ORDER BY slot) INTO _parts
    FROM public.rami_participants WHERE game_id=_game_id AND NOT forfeited;
  _next := _g.current_turn;
  LOOP
    _next := (_next + 1) % _g.max_players;
    EXIT WHEN _next = ANY(_parts);
  END LOOP;

  UPDATE public.rami_games
     SET state=_state, current_turn=_next, turn_phase='draw',
         turn_deadline=now() + (COALESCE(_cfg.turn_timer_seconds,60) || ' seconds')::interval,
         updated_at=now()
   WHERE id=_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.rami_draw(_game_id uuid, _from text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE _uid uuid := auth.uid(); _g public.rami_games; _slot int; _state jsonb;
  _deck int[]; _discard int[]; _hand int[]; _card int; _hands jsonb; _cfg record;
BEGIN
  SELECT * INTO _g FROM public.rami_games WHERE id=_game_id FOR UPDATE;
  IF _g.status <> 'playing' THEN RAISE EXCEPTION 'partie inactive'; END IF;
  SELECT slot INTO _slot FROM public.rami_participants WHERE game_id=_game_id AND user_id=_uid;
  IF _slot IS NULL OR _slot <> _g.current_turn THEN RAISE EXCEPTION 'pas ton tour'; END IF;
  IF _g.turn_phase <> 'draw' THEN RAISE EXCEPTION 'déjà pioché'; END IF;

  SELECT * INTO _cfg FROM public._game_cfg('rami');

  _state := _g.state;
  _deck := ARRAY(SELECT jsonb_array_elements_text(_state->'deck'))::int[];
  _discard := ARRAY(SELECT jsonb_array_elements_text(_state->'discard'))::int[];
  _hand := ARRAY(SELECT jsonb_array_elements_text(_state->'hands'->_uid::text))::int[];
  IF _from = 'discard' THEN
    IF array_length(_discard,1) IS NULL THEN RAISE EXCEPTION 'défausse vide'; END IF;
    _card := _discard[array_length(_discard,1)];
    _discard := _discard[1:array_length(_discard,1)-1];
  ELSE
    IF array_length(_deck,1) IS NULL THEN
      IF array_length(_discard,1) <= 1 THEN RAISE EXCEPTION 'plus de cartes'; END IF;
      _deck := _discard[1:array_length(_discard,1)-1];
      _discard := ARRAY[_discard[array_length(_discard,1)]];
      _deck := (SELECT array_agg(c ORDER BY random()) FROM unnest(_deck) c);
    END IF;
    _card := _deck[1];
    _deck := _deck[2:array_length(_deck,1)];
  END IF;
  _hand := array_append(_hand, _card);
  _hands := jsonb_set(_state->'hands', ARRAY[_uid::text], to_jsonb(_hand));
  _state := jsonb_set(_state, '{deck}', to_jsonb(_deck));
  _state := jsonb_set(_state, '{discard}', to_jsonb(_discard));
  _state := jsonb_set(_state, '{hands}', _hands);

  UPDATE public.rami_games
     SET state = _state,
         turn_phase = 'play',
         turn_deadline = now() + (COALESCE(_cfg.turn_timer_seconds, 60) || ' seconds')::interval,
         updated_at = now()
   WHERE id = _game_id;

  UPDATE public.rami_participants SET hand_count=array_length(_hand,1)
   WHERE game_id=_game_id AND user_id=_uid;
END $function$
;

CREATE OR REPLACE FUNCTION public.rami_forfeit(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _uid uuid := auth.uid();
  _g public.rami_games;
  _alive uuid[];
  _winner uuid;
  _payout numeric;
  _comm numeric;
  _humans int;
BEGIN
  SELECT * INTO _g FROM public.rami_games WHERE id = _game_id FOR UPDATE;
  IF _g.status NOT IN ('waiting', 'playing') THEN RETURN; END IF;

  UPDATE public.rami_participants SET forfeited = true WHERE game_id = _game_id AND user_id = _uid;

  IF _g.status = 'waiting' THEN
    UPDATE public.rami_games SET status = 'finished', finished_at = now() WHERE id = _game_id;
    IF _g.stake > 0 THEN
      UPDATE public.profiles SET balance_ar = balance_ar + _g.stake WHERE id = _uid;
      INSERT INTO public.transactions (user_id, type, amount, ref_id, note)
      VALUES (_uid, 'rami_refund', _g.stake, _game_id, 'Refund rami');
    END IF;
    RETURN;
  END IF;

  _humans := public._rami_active_humans(_game_id);
  IF _humans = 0 THEN
    UPDATE public.rami_games SET status = 'finished', finished_at = now() WHERE id = _game_id;
    RETURN;
  END IF;

  SELECT array_agg(user_id) INTO _alive FROM public.rami_participants WHERE game_id = _game_id AND NOT forfeited;
  IF COALESCE(array_length(_alive, 1), 0) = 1 THEN
    _winner := _alive[1];
    _comm := round(_g.pot * _g.commission_pct / 100.0, 0);
    _payout := _g.pot - _comm;
    UPDATE public.profiles SET balance_ar = balance_ar + _payout WHERE id = _winner;
    INSERT INTO public.transactions (user_id, type, amount, ref_id, note)
    VALUES (_winner, 'rami_win', _payout, _game_id, 'Win rami by forfeit');
    UPDATE public.rami_games SET status = 'finished', winner_id = _winner, finished_at = now() WHERE id = _game_id;
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.rami_join(_game_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _uid uuid := auth.uid();
  _g public.rami_games;
  _bal numeric;
  _name text;
  _count int;
  _slot int;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO _g FROM public.rami_games WHERE id = _game_id FOR UPDATE;
  IF _g.id IS NULL          THEN RAISE EXCEPTION 'partie introuvable'; END IF;
  IF _g.status <> 'waiting' THEN RAISE EXCEPTION 'partie déjà commencée'; END IF;
  IF _g.is_private          THEN RAISE EXCEPTION 'partie privée — utilise le code pour rejoindre'; END IF;

  IF EXISTS (SELECT 1 FROM public.rami_participants WHERE game_id=_g.id AND user_id=_uid) THEN
    RETURN _g.id;
  END IF;

  SELECT count(*) INTO _count FROM public.rami_participants WHERE game_id = _g.id;
  IF _count >= _g.max_players THEN RAISE EXCEPTION 'partie pleine'; END IF;

  SELECT balance_ar, COALESCE(pseudo,'Joueur') INTO _bal, _name
    FROM public.profiles WHERE id = _uid FOR UPDATE;
  IF _bal IS NULL OR _bal < _g.stake THEN RAISE EXCEPTION 'Solde insuffisant'; END IF;

  -- first free slot in 0.._max-1
  SELECT s.slot INTO _slot
  FROM generate_series(0, _g.max_players - 1) s(slot)
  WHERE s.slot NOT IN (SELECT slot FROM public.rami_participants WHERE game_id = _g.id)
  ORDER BY s.slot LIMIT 1;
  IF _slot IS NULL THEN RAISE EXCEPTION 'partie pleine'; END IF;

  IF _g.stake > 0 THEN
    UPDATE public.profiles SET balance_ar = balance_ar - _g.stake WHERE id = _uid;
    UPDATE public.rami_games SET pot = pot + _g.stake WHERE id = _g.id;
    INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
    VALUES (_uid, 'rami_stake', -_g.stake, _g.id, 'Join rami');
  END IF;

  INSERT INTO public.rami_participants(game_id, user_id, slot, display_name)
  VALUES (_g.id, _uid, _slot, _name);

  RETURN _g.id;
END $function$
;

CREATE OR REPLACE FUNCTION public.rami_join_code(_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _uid uuid := auth.uid();
  _g public.rami_games;
  _slot int;
  _bal numeric;
  _name text;
  _count int;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;

  SELECT * INTO _g FROM public.rami_games WHERE room_code = upper(_code) FOR UPDATE;
  IF _g.id IS NULL THEN RAISE EXCEPTION 'partie introuvable'; END IF;
  IF _g.status <> 'waiting' THEN RAISE EXCEPTION 'partie déjà commencée'; END IF;
  IF EXISTS (SELECT 1 FROM public.rami_participants WHERE game_id = _g.id AND user_id = _uid) THEN RETURN _g.id; END IF;

  SELECT count(*) INTO _count FROM public.rami_participants WHERE game_id = _g.id;
  IF _count >= _g.max_players THEN RAISE EXCEPTION 'partie pleine'; END IF;

  SELECT balance_ar, COALESCE(pseudo, 'Joueur') INTO _bal, _name
    FROM public.profiles
   WHERE id = _uid
   FOR UPDATE;

  IF _bal IS NULL OR _bal < _g.stake THEN RAISE EXCEPTION 'solde insuffisant'; END IF;
  _slot := _count;

  IF _g.stake > 0 THEN
    UPDATE public.profiles SET balance_ar = balance_ar - _g.stake WHERE id = _uid;
    UPDATE public.rami_games SET pot = pot + _g.stake WHERE id = _g.id;
    INSERT INTO public.transactions (user_id, type, amount, ref_id, note)
    VALUES (_uid, 'rami_stake', -_g.stake, _g.id, 'Join rami');
  END IF;

  INSERT INTO public.rami_participants (game_id, user_id, slot, display_name)
  VALUES (_g.id, _uid, _slot, _name);

  RETURN _g.id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.rami_layoff(_game_id uuid, _meld_index integer, _cards integer[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE _uid uuid := auth.uid(); _g public.rami_games; _slot int; _state jsonb;
  _hand int[]; _c int; _new_hand int[]; _melds jsonb; _meld jsonb;
  _existing int[]; _combined int[]; _type text;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO _g FROM public.rami_games WHERE id=_game_id FOR UPDATE;
  IF _g.status <> 'playing' THEN RAISE EXCEPTION 'partie inactive'; END IF;
  SELECT slot INTO _slot FROM public.rami_participants WHERE game_id=_game_id AND user_id=_uid;
  IF _slot IS NULL THEN RAISE EXCEPTION 'non participant'; END IF;
  IF _slot <> _g.current_turn OR _g.turn_phase <> 'play' THEN RAISE EXCEPTION 'pas ton tour'; END IF;

  _state := _g.state;
  _melds := COALESCE(_state->'melds','[]'::jsonb);
  _meld  := _melds -> _meld_index;
  IF _meld IS NULL THEN RAISE EXCEPTION 'combinaison introuvable'; END IF;
  _existing := ARRAY(SELECT jsonb_array_elements_text(_meld->'cards'))::int[];
  _combined := _existing || _cards;
  _type := public._rami_meld_type(_combined, _g.joker_mode, _g.random_joker);
  IF _type IS NULL THEN RAISE EXCEPTION 'ajout invalide'; END IF;

  _hand := ARRAY(SELECT jsonb_array_elements_text(_state->'hands'->_uid::text))::int[];
  _new_hand := _hand;
  FOREACH _c IN ARRAY _cards LOOP
    IF NOT (_c = ANY(_new_hand)) THEN RAISE EXCEPTION 'carte absente'; END IF;
    _new_hand := public._rami_remove_one(_new_hand,_c);
  END LOOP;

  _melds := jsonb_set(_melds, ARRAY[_meld_index::text],
    jsonb_set(_meld, '{cards}', to_jsonb(_combined))
      || jsonb_build_object('type', _type));
  _state := jsonb_set(_state, ARRAY['hands',_uid::text], to_jsonb(_new_hand));
  _state := jsonb_set(_state, '{melds}', _melds);
  UPDATE public.rami_games SET state=_state, updated_at=now() WHERE id=_game_id;
  UPDATE public.rami_participants SET hand_count=COALESCE(array_length(_new_hand,1),0)
    WHERE game_id=_game_id AND user_id=_uid;
END $function$
;

CREATE OR REPLACE FUNCTION public.rami_meld(_game_id uuid, _cards integer[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE _uid uuid := auth.uid(); _g public.rami_games; _slot int; _state jsonb;
  _hand int[]; _c int; _new_hand int[]; _melds jsonb; _type text;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO _g FROM public.rami_games WHERE id=_game_id FOR UPDATE;
  IF _g.status <> 'playing' THEN RAISE EXCEPTION 'partie inactive'; END IF;
  SELECT slot INTO _slot FROM public.rami_participants WHERE game_id=_game_id AND user_id=_uid;
  IF _slot IS NULL THEN RAISE EXCEPTION 'non participant'; END IF;
  IF _slot <> _g.current_turn OR _g.turn_phase <> 'play' THEN RAISE EXCEPTION 'pas ton tour de jouer'; END IF;
  _type := public._rami_meld_type(_cards, _g.joker_mode, _g.random_joker);
  IF _type IS NULL THEN RAISE EXCEPTION 'combinaison invalide'; END IF;

  _state := _g.state;
  _hand := ARRAY(SELECT jsonb_array_elements_text(_state->'hands'->_uid::text))::int[];
  _new_hand := _hand;
  FOREACH _c IN ARRAY _cards LOOP
    IF NOT (_c = ANY(_new_hand)) THEN RAISE EXCEPTION 'carte absente de la main'; END IF;
    _new_hand := public._rami_remove_one(_new_hand,_c);
  END LOOP;
  _melds := COALESCE(_state->'melds','[]'::jsonb) || jsonb_build_array(
    jsonb_build_object('player',_uid::text,'cards',to_jsonb(_cards),'type',_type)
  );
  _state := jsonb_set(_state, ARRAY['hands',_uid::text], to_jsonb(_new_hand));
  _state := jsonb_set(_state, '{melds}', _melds);
  UPDATE public.rami_games SET state=_state, updated_at=now() WHERE id=_game_id;
  UPDATE public.rami_participants SET hand_count=COALESCE(array_length(_new_hand,1),0)
    WHERE game_id=_game_id AND user_id=_uid;
END $function$
;

CREATE OR REPLACE FUNCTION public.rami_request_refund(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE _uid uuid := auth.uid(); _g rami_games; _hand int[]; _stake numeric;
  _has_carre boolean := false; _has_trio boolean := false;
  _has_run3 boolean := false; _has_run4 boolean := false;
  _refunded jsonb; _ok boolean := false;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO _g FROM rami_games WHERE id=_game_id FOR UPDATE;
  IF _g.status <> 'playing' THEN RAISE EXCEPTION 'partie inactive'; END IF;

  _refunded := COALESCE(_g.state->'refunded','{}'::jsonb);
  IF _refunded ? _uid::text THEN RAISE EXCEPTION 'mise déjà remboursée'; END IF;

  _hand := ARRAY(SELECT jsonb_array_elements_text(_g.state->'hands'->_uid::text))::int[];
  IF COALESCE(array_length(_hand,1),0) = 0 THEN RAISE EXCEPTION 'main vide'; END IF;

  -- Check via brute search of all valid sub-melds in hand
  -- Heuristic: try every 4-subset for carré, 3-subset for trio, 3-4 contiguous for run.
  -- We rely on _rami_meld_type to type any subset.
  DECLARE _n int := array_length(_hand,1);
    _i int; _j int; _k int; _l int;
    _sub int[]; _t text;
  BEGIN
    -- Carrés (4)
    FOR _i IN 1.._n-3 LOOP FOR _j IN _i+1.._n-2 LOOP
      FOR _k IN _j+1.._n-1 LOOP FOR _l IN _k+1.._n LOOP
        _sub := ARRAY[_hand[_i],_hand[_j],_hand[_k],_hand[_l]];
        _t := public._rami_meld_type(_sub,_g.joker_mode,_g.random_joker);
        IF _t='carre' THEN _has_carre := true; END IF;
        IF _t='run' THEN _has_run4 := true; END IF;
      END LOOP; END LOOP;
    END LOOP; END LOOP;
    -- Trios + Runs of 3
    FOR _i IN 1.._n-2 LOOP FOR _j IN _i+1.._n-1 LOOP FOR _k IN _j+1.._n LOOP
      _sub := ARRAY[_hand[_i],_hand[_j],_hand[_k]];
      _t := public._rami_meld_type(_sub,_g.joker_mode,_g.random_joker);
      IF _t='trio' THEN _has_trio := true; END IF;
      IF _t='run' THEN _has_run3 := true; END IF;
    END LOOP; END LOOP; END LOOP;
  END;

  IF (_has_carre AND _has_run3) OR (_has_trio AND _has_run4) THEN _ok := true; END IF;
  IF NOT _ok THEN RAISE EXCEPTION 'conditions de retour non remplies'; END IF;

  _stake := COALESCE(_g.stake,0);
  IF _stake > 0 THEN
    UPDATE public.profiles SET balance_ar=balance_ar+_stake WHERE id=_uid;
    INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
    VALUES (_uid,'rami_refund',_stake,_game_id,'Retour de mise rami');
    UPDATE public.rami_games SET pot=GREATEST(pot-_stake,0) WHERE id=_game_id;
  END IF;
  UPDATE public.rami_games
     SET state = jsonb_set(state,'{refunded}',COALESCE(state->'refunded','{}'::jsonb) || jsonb_build_object(_uid::text,true))
   WHERE id=_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.rami_set_ready(_game_id uuid, _ready boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_g public.rami_games;
  v_total int;
  v_ready int;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO v_g FROM public.rami_games WHERE id = _game_id FOR UPDATE;
  IF v_g.id IS NULL THEN RAISE EXCEPTION 'game not found'; END IF;
  IF v_g.status <> 'waiting' THEN RETURN; END IF;

  UPDATE public.rami_participants
     SET ready = COALESCE(_ready, false)
   WHERE game_id = _game_id AND user_id = v_uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'not a participant'; END IF;

  SELECT count(*), count(*) FILTER (WHERE ready)
    INTO v_total, v_ready
    FROM public.rami_participants WHERE game_id = _game_id;

  IF v_total = v_g.max_players AND v_ready = v_total THEN
    PERFORM public.rami_start(_game_id);
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.rami_start(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _g public.rami_games;
  _rows RECORD;
  _deck int[]; _i int; _j int; _tmp int;
  _hands jsonb := '{}'::jsonb; _hand int[]; _state jsonb;
  _max int; _rj int := NULL; _first int; _top int; _key text;
  _n int;
BEGIN
  SELECT * INTO _g FROM public.rami_games WHERE id=_game_id FOR UPDATE;
  IF _g.status <> 'waiting' THEN RETURN; END IF;

  SELECT count(*) INTO _n FROM public.rami_participants WHERE game_id=_game_id;
  IF _n < 2 THEN RAISE EXCEPTION 'pas assez de joueurs'; END IF;

  IF _g.joker_mode IN ('classique','double') THEN _max := 56; ELSE _max := 52; END IF;
  _deck := ARRAY(SELECT generate_series(0,_max-1));

  FOR _i IN REVERSE _max..2 LOOP
    _j := 1 + floor(random()*_i)::int;
    _tmp := _deck[_i]; _deck[_i] := _deck[_j]; _deck[_j] := _tmp;
  END LOOP;

  FOR _rows IN SELECT slot, user_id, is_bot FROM public.rami_participants
                WHERE game_id=_game_id ORDER BY slot LOOP
    _hand := _deck[1:13];
    _deck := _deck[14:array_length(_deck,1)];
    _key := CASE WHEN COALESCE(_rows.is_bot,false) OR _rows.user_id IS NULL
                 THEN 'bot:' || _rows.slot::text
                 ELSE _rows.user_id::text END;
    _hands := _hands || jsonb_build_object(_key, to_jsonb(_hand));
    UPDATE public.rami_participants SET hand_count=13
      WHERE game_id=_game_id AND slot=_rows.slot;
  END LOOP;

  IF _g.joker_mode IN ('aleatoire','double') THEN
    _i := 1;
    WHILE _i <= array_length(_deck,1) AND _deck[_i] >= 52 LOOP _i := _i + 1; END LOOP;
    IF _i <= array_length(_deck,1) THEN
      _rj := _deck[_i];
      _deck := _deck[1:_i-1] || _deck[_i+1:array_length(_deck,1)];
    END IF;
  END IF;

  _top := _deck[1];
  _deck := _deck[2:array_length(_deck,1)];
  _first := floor(random() * _n)::int;

  _state := jsonb_build_object(
    'deck', to_jsonb(_deck),
    'discards', jsonb_build_object('_seed', jsonb_build_array(_top)),
    'last_discard_by', '_seed',
    'hands', _hands,
    'melds', '[]'::jsonb,
    'first_player', _first
  );

  UPDATE public.rami_games
    SET status='playing', state=_state, started_at=now(),
        current_turn=_first, turn_phase='draw',
        random_joker=_rj,
        turn_deadline=now() + (COALESCE((SELECT turn_timer_seconds FROM public._game_cfg('rami')),60) || ' seconds')::interval
  WHERE id=_game_id;

  PERFORM public._rami_autoplay_bots(_game_id);
END $function$
;

CREATE OR REPLACE FUNCTION public.rami_start_solo_bot(_max_players integer DEFAULT 2, _difficulty text DEFAULT 'medium'::text, _joker_mode text DEFAULT 'classique'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_game_id uuid;
  v_code text;
  v_name text;
  v_intel int;
  v_paused boolean;
  v_banned boolean;
  v_slot int;
  v_bot_names text[] := ARRAY['Bot Rija','Bot Naina','Bot Hery','Bot Voara'];
  v_max int;
  v_deck int[]; v_i int; v_j int; v_tmp int; v_deck_size int;
  v_hands jsonb := '{}'::jsonb; v_hand int[]; v_key text;
  v_rj int := NULL; v_top int; v_first int;
  v_state jsonb;
  v_parts_count int;
BEGIN
  PERFORM public._assert_solo_bot_enabled();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF _max_players < 2 OR _max_players > 4 THEN RAISE EXCEPTION 'Joueurs invalides (2-4)'; END IF;
  IF _joker_mode NOT IN ('sans','aleatoire','classique','double') THEN
    _joker_mode := 'classique';
  END IF;

  SELECT paused INTO v_paused FROM public.app_settings WHERE id=1;
  IF COALESCE(v_paused,false) THEN RAISE EXCEPTION 'Application en pause'; END IF;

  SELECT banned, COALESCE(pseudo,'Joueur') INTO v_banned, v_name FROM public.profiles WHERE id=v_uid;
  IF COALESCE(v_banned,false) THEN RAISE EXCEPTION 'Compte banni'; END IF;

  CASE lower(_difficulty)
    WHEN 'easy' THEN v_intel := 30;
    WHEN 'hard' THEN v_intel := 95;
    ELSE v_intel := 70;
  END CASE;

  v_code := public._rami_gen_code();

  INSERT INTO public.rami_games (
    room_code, is_private, stake, max_players, commission_pct, created_by, pot, joker_mode, status
  ) VALUES (
    v_code, true, 0, _max_players, 0, v_uid, 0, _joker_mode, 'waiting'
  ) RETURNING id INTO v_game_id;

  -- Human at slot 0
  INSERT INTO public.rami_participants(game_id, user_id, slot, display_name, ready, is_bot)
    VALUES (v_game_id, v_uid, 0, v_name, true, false);

  -- Bots at slots 1..N-1
  FOR v_slot IN 1.._max_players - 1 LOOP
    INSERT INTO public.rami_participants(
      game_id, user_id, slot, display_name, ready, is_bot, bot_name, bot_intelligence
    ) VALUES (
      v_game_id, NULL, v_slot, v_bot_names[v_slot], true, true, v_bot_names[v_slot], v_intel
    );
  END LOOP;

  -- Build deck according to joker mode
  IF _joker_mode IN ('classique','double') THEN v_max := 56; ELSE v_max := 52; END IF;
  v_deck := ARRAY(SELECT generate_series(0, v_max-1));

  -- Fisher-Yates shuffle
  FOR v_i IN REVERSE v_max..2 LOOP
    v_j := 1 + floor(random()*v_i)::int;
    v_tmp := v_deck[v_i]; v_deck[v_i] := v_deck[v_j]; v_deck[v_j] := v_tmp;
  END LOOP;

  -- Deal 13 cards to each participant (human uses uid key, bots use 'bot:<slot>')
  FOR v_slot IN 0.._max_players - 1 LOOP
    v_hand := v_deck[1:13];
    v_deck := v_deck[14:array_length(v_deck,1)];
    IF v_slot = 0 THEN
      v_key := v_uid::text;
    ELSE
      v_key := 'bot:' || v_slot::text;
    END IF;
    v_hands := v_hands || jsonb_build_object(v_key, to_jsonb(v_hand));
    UPDATE public.rami_participants SET hand_count = 13
      WHERE game_id = v_game_id AND slot = v_slot;
  END LOOP;

  -- Random joker (modes aleatoire/double)
  IF _joker_mode IN ('aleatoire','double') THEN
    v_i := 1;
    WHILE v_i <= array_length(v_deck,1) AND v_deck[v_i] >= 52 LOOP v_i := v_i + 1; END LOOP;
    IF v_i <= array_length(v_deck,1) THEN
      v_rj := v_deck[v_i];
      v_deck := v_deck[1:v_i-1] || v_deck[v_i+1:array_length(v_deck,1)];
    END IF;
  END IF;

  -- First discard
  v_top := v_deck[1];
  v_deck := v_deck[2:array_length(v_deck,1)];

  -- Random first player
  v_first := floor(random() * _max_players)::int;

  v_state := jsonb_build_object(
    'deck', to_jsonb(v_deck),
    'discard', jsonb_build_array(v_top),
    'hands', v_hands,
    'melds', '[]'::jsonb,
    'first_player', v_first
  );

  UPDATE public.rami_games SET
    status = 'playing',
    state = v_state,
    started_at = now(),
    current_turn = v_first,
    turn_phase = 'draw',
    random_joker = v_rj,
    turn_deadline = now() + interval '60 seconds'
  WHERE id = v_game_id;

  -- Autoplay if first player is a bot
  PERFORM public._rami_autoplay_bots(v_game_id);

  RETURN v_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.rami_tick(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _g public.rami_games; _state jsonb; _uid uuid; _hand int[]; _new_hand int[];
  _deck int[]; _card int; _next int; _cfg record; _skips int;
  _best_card int; _best_pts int := -1; _pts int; _rank int; _c int;
  _is_bot boolean; _key text;
  _discards jsonb; _pile int[]; _reshuffle jsonb;
BEGIN
  SELECT * INTO _g FROM public.rami_games WHERE id=_game_id FOR UPDATE;
  IF _g.status <> 'playing' THEN RETURN; END IF;

  SELECT COALESCE(is_bot,false), user_id INTO _is_bot, _uid
    FROM public.rami_participants WHERE game_id=_game_id AND slot=_g.current_turn;

  IF _is_bot THEN
    PERFORM public._rami_autoplay_bots(_game_id);
    RETURN;
  END IF;

  IF _g.turn_deadline IS NULL OR _g.turn_deadline > now() THEN RETURN; END IF;
  SELECT * INTO _cfg FROM public._game_cfg('rami');
  _skips := COALESCE((_g.turn_skips->>_uid::text)::int, 0) + 1;

  IF _skips >= COALESCE(_cfg.max_turn_skips,3) THEN
    UPDATE public.rami_participants SET forfeited = true WHERE game_id=_game_id AND user_id=_uid;
    IF (SELECT count(*) FROM public.rami_participants WHERE game_id=_game_id AND NOT forfeited) <= 1 THEN
      DECLARE _win uuid;
      BEGIN
        SELECT user_id INTO _win FROM public.rami_participants WHERE game_id=_game_id AND NOT forfeited LIMIT 1;
        UPDATE public.rami_games SET status='finished', winner_id=_win, finished_at=now() WHERE id=_game_id;
        IF _win IS NOT NULL THEN
          UPDATE public.profiles SET balance_ar = balance_ar + (_g.pot * (100 - _g.commission_pct) / 100) WHERE id=_win;
          INSERT INTO public.transactions(user_id,type,amount,ref_id,note)
            VALUES (_win,'rami_win', _g.pot * (100 - _g.commission_pct) / 100, _game_id, 'Rami win (forfait)');
        END IF;
        RETURN;
      END;
    END IF;
  END IF;

  _state := public._rami_normalize_state(_g.state);
  _key := _uid::text;
  _deck := COALESCE(ARRAY(SELECT jsonb_array_elements_text(_state->'deck'))::int[], ARRAY[]::int[]);
  _discards := public._rami_discards_map(_state);
  _hand := COALESCE(ARRAY(SELECT jsonb_array_elements_text(_state->'hands'->_key))::int[], ARRAY[]::int[]);

  IF _g.turn_phase = 'draw' THEN
    IF COALESCE(array_length(_deck,1),0) = 0 THEN
      _reshuffle := public._rami_reshuffle(_state);
      _deck := COALESCE(ARRAY(SELECT jsonb_array_elements_text(_reshuffle->'deck'))::int[], ARRAY[]::int[]);
      _discards := _reshuffle->'discards';
      IF COALESCE(array_length(_deck,1),0) = 0 THEN
        UPDATE public.rami_games SET status='finished', finished_at=now(),
          state = jsonb_set(_state,'{end_reason}', to_jsonb('deck exhausted'::text))
          WHERE id=_game_id;
        RETURN;
      END IF;
    END IF;
    _card := _deck[1]; _deck := _deck[2:array_length(_deck,1)];
    _hand := array_append(_hand, _card);
  END IF;

  FOREACH _c IN ARRAY _hand LOOP
    IF public._rami_is_joker(_c, _g.joker_mode, _g.random_joker) THEN CONTINUE; END IF;
    _rank := _c % 13;
    _pts := CASE WHEN _rank = 0 THEN 11
                 WHEN _rank >= 10 THEN 10
                 ELSE _rank + 1 END;
    IF _pts > _best_pts THEN _best_pts := _pts; _best_card := _c; END IF;
  END LOOP;
  IF _best_card IS NULL THEN
    _best_card := _hand[1 + floor(random()*array_length(_hand,1))::int];
  END IF;
  _card := _best_card;

  _new_hand := public._rami_remove_one(_hand, _card);
  _pile := COALESCE(ARRAY(SELECT jsonb_array_elements_text(_discards->_key))::int[], ARRAY[]::int[]);
  _pile := array_append(_pile, _card);
  _discards := jsonb_set(_discards, ARRAY[_key], to_jsonb(_pile), true);

  _state := jsonb_set(_state, '{deck}', to_jsonb(_deck));
  _state := jsonb_set(_state, '{discards}', _discards);
  _state := jsonb_set(_state, '{last_discard_by}', to_jsonb(_key));
  _state := jsonb_set(_state, ARRAY['hands',_key], to_jsonb(_new_hand));
  _state := _state - 'discard';
  UPDATE public.rami_participants SET hand_count=array_length(_new_hand,1) WHERE game_id=_game_id AND user_id=_uid;

  _next := _g.current_turn;
  LOOP
    _next := (_next + 1) % _g.max_players;
    EXIT WHEN _next IN (SELECT slot FROM public.rami_participants WHERE game_id=_game_id AND NOT forfeited);
  END LOOP;

  UPDATE public.rami_games SET state=_state, current_turn=_next, turn_phase='draw',
    turn_skips = jsonb_set(COALESCE(_g.turn_skips,'{}'::jsonb), ARRAY[_uid::text], to_jsonb(_skips)),
    turn_deadline = now() + (COALESCE(_cfg.turn_timer_seconds,60) || ' seconds')::interval,
    updated_at=now()
    WHERE id=_game_id;

  PERFORM public._rami_autoplay_bots(_game_id);
END $function$
;

CREATE OR REPLACE FUNCTION public.rami_validate_hand(_game_id uuid, _layout jsonb, _discard_card integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _uid uuid := auth.uid();
  _g public.rami_games;
  _slot int;
  _state jsonb;
  _hand int[];
  _all_cards int[] := ARRAY[]::int[];
  _grp jsonb;
  _grp_arr int[];
  _mtype text;
  _c int;
  _melds jsonb := '[]'::jsonb;
  _discard int[];
  _payout numeric;
  _comm numeric;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'auth required'; END IF;
  SELECT * INTO _g FROM public.rami_games WHERE id = _game_id FOR UPDATE;
  IF _g.status <> 'playing' THEN RAISE EXCEPTION 'partie inactive'; END IF;
  SELECT slot INTO _slot FROM public.rami_participants WHERE game_id = _game_id AND user_id = _uid;
  IF _slot IS NULL THEN RAISE EXCEPTION 'non participant'; END IF;
  IF _slot <> _g.current_turn OR _g.turn_phase <> 'play' THEN
    RAISE EXCEPTION 'ce n''est pas ton tour de valider';
  END IF;

  _state := _g.state;
  _hand := COALESCE(ARRAY(SELECT jsonb_array_elements_text(_state->'hands'->_uid::text))::int[], ARRAY[]::int[]);

  -- Vérifie que la carte à défausser est dans la main
  IF NOT (_discard_card = ANY(_hand)) THEN
    RAISE EXCEPTION 'carte à défausser absente de la main';
  END IF;

  -- Valide chaque groupe
  FOR _grp IN SELECT * FROM jsonb_array_elements(COALESCE(_layout, '[]'::jsonb)) LOOP
    _grp_arr := ARRAY(SELECT jsonb_array_elements_text(_grp))::int[];
    IF COALESCE(array_length(_grp_arr, 1), 0) < 3 THEN
      RAISE EXCEPTION 'un groupe doit contenir au moins 3 cartes';
    END IF;
    _mtype := public._rami_meld_type(_grp_arr, _g.joker_mode, _g.random_joker);
    IF _mtype IS NULL THEN
      RAISE EXCEPTION 'un des groupes est invalide (ni trio, ni carré, ni suite)';
    END IF;
    _all_cards := _all_cards || _grp_arr;
    _melds := _melds || jsonb_build_array(
      jsonb_build_object('player', _uid::text, 'cards', to_jsonb(_grp_arr), 'type', _mtype)
    );
  END LOOP;

  -- Ajoute la carte défaussée à la liste totale attendue
  _all_cards := _all_cards || ARRAY[_discard_card];

  -- Toutes les cartes de la main doivent être utilisées (validation + défausse)
  IF COALESCE(array_length(_all_cards, 1), 0) <> COALESCE(array_length(_hand, 1), 0) THEN
    RAISE EXCEPTION 'toutes tes cartes doivent être placées dans des combinaisons';
  END IF;

  -- Vérifie que chaque carte du layout est bien dans la main (multi-ensemble)
  DECLARE
    _remaining int[] := _hand;
  BEGIN
    FOREACH _c IN ARRAY _all_cards LOOP
      IF NOT (_c = ANY(_remaining)) THEN
        RAISE EXCEPTION 'carte % absente de la main', _c;
      END IF;
      _remaining := public._rami_remove_one(_remaining, _c);
    END LOOP;
  END;

  -- OK : pose les melds, défausse la carte, marque gagnant
  _discard := COALESCE(ARRAY(SELECT jsonb_array_elements_text(_state->'discard'))::int[], ARRAY[]::int[]);
  _discard := array_append(_discard, _discard_card);
  _state := jsonb_set(_state, ARRAY['hands', _uid::text], to_jsonb(ARRAY[]::int[]));
  _state := jsonb_set(_state, '{discard}', to_jsonb(_discard));
  _state := jsonb_set(_state, '{melds}', (COALESCE(_state->'melds','[]'::jsonb) || _melds));

  _comm := round(_g.pot * _g.commission_pct / 100.0, 0);
  _payout := _g.pot - _comm;

  UPDATE public.rami_participants
     SET hand_count = 0
   WHERE game_id = _game_id AND user_id = _uid;

  IF _payout > 0 THEN
    UPDATE public.profiles SET balance_ar = balance_ar + _payout WHERE id = _uid;
    INSERT INTO public.transactions(user_id, type, amount, ref_id, note)
    VALUES (_uid, 'rami_win', _payout, _game_id, 'Rami win (validation)');
  END IF;

  UPDATE public.rami_games
     SET status = 'finished',
         winner_id = _uid,
         finished_at = now(),
         state = _state,
         updated_at = now()
   WHERE id = _game_id;

  RETURN jsonb_build_object('ok', true, 'payout', _payout);
END $function$
;

CREATE OR REPLACE FUNCTION public.request_password_reset(_contact text, _type text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid;
  v_code text;
  v_norm text;
  v_existing public.password_reset_requests%ROWTYPE;
  v_generic jsonb := jsonb_build_object('status','pending','already',false,'message','Si un compte correspond, une demande a été créée.');
BEGIN
  IF _type NOT IN ('email','phone') THEN RETURN v_generic; END IF;
  v_norm := trim(coalesce(_contact,''));
  IF _type = 'email' THEN v_norm := lower(v_norm); END IF;
  IF length(v_norm) < 3 THEN RETURN v_generic; END IF;

  IF _type = 'email' THEN
    SELECT id INTO v_uid FROM public.profiles WHERE lower(email) = v_norm LIMIT 1;
  ELSE
    SELECT id INTO v_uid FROM public.profiles WHERE phone = v_norm LIMIT 1;
  END IF;

  IF v_uid IS NULL THEN
    RETURN v_generic;
  END IF;

  SELECT * INTO v_existing
  FROM public.password_reset_requests
  WHERE user_id = v_uid
    AND contact_type = _type
    AND status IN ('pending','sent')
    AND created_at > now() - interval '24 hours'
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN v_generic;
  END IF;

  v_code := lpad((floor(random()*1000000))::int::text, 6, '0');

  INSERT INTO public.password_reset_requests(user_id, contact, contact_type, code, status)
  VALUES (v_uid, v_norm, _type, v_code, 'pending');

  RETURN v_generic;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.request_phone_verification(_phone text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_code text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth'; END IF;
  v_code := lpad((floor(random()*1000000))::int::text, 6, '0');
  UPDATE public.profiles
    SET phone = _phone,
        phone_verified = false,
        phone_verification_code = v_code,
        phone_verification_code_hash = encode(extensions.digest(v_code || id::text, 'sha256'), 'hex'),
        phone_verification_requested_at = now()
    WHERE id = v_uid;
  RETURN v_code;
END $function$
;

CREATE OR REPLACE FUNCTION public.request_withdrawal(_amount numeric, _method text, _user_phone text, _recipient_name text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_balance numeric;
  v_min numeric;
  v_pending numeric;
  v_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentification requise'; END IF;
  IF _amount IS NULL OR _amount <= 0 THEN RAISE EXCEPTION 'Montant invalide'; END IF;
  IF _method IS NULL OR btrim(_method) = '' THEN RAISE EXCEPTION 'Opérateur requis'; END IF;
  IF _user_phone IS NULL OR btrim(_user_phone) = '' THEN RAISE EXCEPTION 'Numéro requis'; END IF;

  SELECT COALESCE(min_withdraw, 0) INTO v_min FROM public.app_settings WHERE id = 1;
  IF v_min IS NOT NULL AND _amount < v_min THEN
    RAISE EXCEPTION 'Montant inférieur au minimum autorisé (% Ar)', v_min;
  END IF;

  SELECT balance_ar INTO v_balance FROM public.profiles WHERE id = v_uid FOR UPDATE;
  IF v_balance IS NULL THEN RAISE EXCEPTION 'Profil introuvable'; END IF;

  -- Vérifie solde en tenant compte des retraits pending déjà en cours
  SELECT COALESCE(SUM(amount),0) INTO v_pending FROM public.withdrawals
    WHERE user_id = v_uid AND status = 'pending';
  IF v_balance < (_amount + v_pending) THEN
    RAISE EXCEPTION 'Solde insuffisant (retraits en attente inclus)';
  END IF;

  INSERT INTO public.withdrawals(user_id, amount, method, user_phone, recipient_name, status)
  VALUES (v_uid, _amount, _method, btrim(_user_phone), NULLIF(btrim(COALESCE(_recipient_name,'')), ''), 'pending')
  RETURNING id INTO v_id;

  INSERT INTO public.notifications(user_id, kind, title, body, link, ref_id)
  VALUES (
    v_uid, 'withdraw',
    'Demande de retrait enregistrée',
    format('Votre demande de %s Ar est en attente de validation.', to_char(_amount, 'FM999G999G999')),
    '/history', v_id
  );

  RETURN v_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.resolve_room_code(_code text)
 RETURNS TABLE(slug text, game_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_code text := upper(trim(_code)); v_id uuid;
BEGIN
  SELECT id INTO v_id FROM public.ludo_games     WHERE room_code = v_code AND status = 'open' LIMIT 1;
  IF FOUND THEN RETURN QUERY SELECT 'ludo'::text, v_id; RETURN; END IF;
  SELECT id INTO v_id FROM public.domino_games   WHERE room_code = v_code AND status = 'open' LIMIT 1;
  IF FOUND THEN RETURN QUERY SELECT 'domino'::text, v_id; RETURN; END IF;
  SELECT id INTO v_id FROM public.fanorona_games WHERE room_code = v_code AND status = 'open' LIMIT 1;
  IF FOUND THEN RETURN QUERY SELECT 'fanorona'::text, v_id; RETURN; END IF;
  SELECT id INTO v_id FROM public.chess_games    WHERE room_code = v_code AND status = 'open' LIMIT 1;
  IF FOUND THEN RETURN QUERY SELECT 'chess'::text, v_id; RETURN; END IF;
  SELECT id INTO v_id FROM public.rami_games     WHERE room_code = v_code AND status = 'open' LIMIT 1;
  IF FOUND THEN RETURN QUERY SELECT 'rami'::text, v_id; RETURN; END IF;
  SELECT id INTO v_id FROM public.poker_games    WHERE room_code = v_code AND status = 'open' LIMIT 1;
  IF FOUND THEN RETURN QUERY SELECT 'poker'::text, v_id; RETURN; END IF;
  RAISE EXCEPTION 'Code introuvable ou partie déjà commencée : %', v_code;
END $function$
;

CREATE OR REPLACE FUNCTION public.run_finance_tests()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_admin uuid := gen_random_uuid();
  v_p1    uuid := gen_random_uuid();
  v_p2    uuid := gen_random_uuid();
  v_ids uuid[];
  v_dep_id uuid; v_wd_id uuid; v_game uuid;
  v_cpct numeric; v_bal numeric; v_bal2 numeric; v_net numeric; v_debt numeric;
  v_ok boolean; v_err text;
  v_report text := '';
  v_saved_uid text;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Réservé admin'; END IF;
  v_saved_uid := current_setting('request.jwt.claim.sub', true);
  v_ids := ARRAY[v_admin, v_p1, v_p2];

  INSERT INTO auth.users(id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
  VALUES
    (v_admin,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','ftest-admin+'||v_admin::text||'@lovable.local','x',now(),now()),
    (v_p1,   '00000000-0000-0000-0000-000000000000','authenticated','authenticated','ftest-p1+'||v_p1::text||'@lovable.local','x',now(),now()),
    (v_p2,   '00000000-0000-0000-0000-000000000000','authenticated','authenticated','ftest-p2+'||v_p2::text||'@lovable.local','x',now(),now());

  UPDATE public.profiles SET balance_ar = 0 WHERE id = ANY(v_ids);
  INSERT INTO public.user_roles(user_id, role) VALUES (v_admin, 'admin') ON CONFLICT DO NOTHING;
  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);

  INSERT INTO public.deposits(user_id,amount,method,reference,user_phone,status)
    VALUES (v_p1,10000,'mvola','FT-'||substr(v_p1::text,1,6),'0340000000','pending') RETURNING id INTO v_dep_id;
  PERFORM public.admin_process_deposit(v_dep_id,true);
  SELECT balance_ar INTO v_bal FROM public.profiles WHERE id=v_p1;
  IF v_bal<>10000 THEN RAISE EXCEPTION 'FAIL T1: %', v_bal; END IF;
  v_report := v_report || E'PASS T1 — Dépôt approuvé crédite le solde\n';

  INSERT INTO public.withdrawal_debts(user_id, amount_ar) VALUES (v_p2, 3000);
  INSERT INTO public.deposits(user_id,amount,method,reference,user_phone,status)
    VALUES (v_p2,5000,'mvola','FT-'||substr(v_p2::text,1,6),'0340000001','pending') RETURNING id INTO v_dep_id;
  PERFORM public.admin_process_deposit(v_dep_id,true);
  SELECT balance_ar INTO v_bal FROM public.profiles WHERE id=v_p2;
  SELECT COALESCE(SUM(amount_ar),0) INTO v_debt FROM public.withdrawal_debts WHERE user_id=v_p2;
  IF v_bal<>2000 OR v_debt<>0 THEN RAISE EXCEPTION 'FAIL T2: solde=% dette=%', v_bal, v_debt; END IF;
  v_report := v_report || E'PASS T2 — Dépôt éponge la dette avant de créditer\n';

  UPDATE public.profiles SET balance_ar=20000 WHERE id=v_p1;
  PERFORM set_config('request.jwt.claim.sub', v_p1::text, true);
  SELECT public.request_withdrawal(15000,'mvola','0340000000','Joueur 1') INTO v_wd_id;
  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  PERFORM public.admin_process_withdrawal(v_wd_id,true);
  SELECT balance_ar INTO v_bal FROM public.profiles WHERE id=v_p1;
  IF v_bal<>0 THEN RAISE EXCEPTION 'FAIL T3: solde=%', v_bal; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.transactions WHERE ref_id=v_wd_id AND type='balance_reset' AND amount=-5000) THEN
    RAISE EXCEPTION 'FAIL T3: balance_reset -5000 introuvable';
  END IF;
  v_report := v_report || E'PASS T3 — Retrait approuvé remet à 0 + trace balance_reset\n';

  UPDATE public.profiles SET balance_ar=100 WHERE id=v_p2;
  PERFORM set_config('request.jwt.claim.sub', v_p2::text, true);
  v_ok := false;
  BEGIN PERFORM public.request_withdrawal(5000,'mvola','0340000001','Joueur 2');
  EXCEPTION WHEN OTHERS THEN v_ok:=true; v_err:=SQLERRM; END;
  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  IF NOT v_ok THEN RAISE EXCEPTION 'FAIL T4: aurait dû échouer'; END IF;
  v_report := v_report || format(E'PASS T4 — Retrait refusé si solde insuffisant (%s)\n', v_err);

  UPDATE public.profiles SET balance_ar=0 WHERE id=v_p1;
  INSERT INTO public.ludo_games(host_id,max_players,stake,pot,status,mode)
    VALUES (v_p1,2,1000,2000,'playing','classic') RETURNING id, commission_pct INTO v_game, v_cpct;
  INSERT INTO public.ludo_participants(game_id,user_id,slot,color,display_name,is_bot)
    VALUES (v_game,v_p1,0,'red','Joueur 1',false),(v_game,v_p2,1,'green','Joueur 2',false);
  PERFORM public.finish_game(v_game, v_p1);
  SELECT balance_ar INTO v_bal FROM public.profiles WHERE id=v_p1;
  v_net := 2000 * (100 - v_cpct) / 100.0;
  IF v_bal<>v_net THEN RAISE EXCEPTION 'FAIL T5: attendu % obtenu %', v_net, v_bal; END IF;
  v_report := v_report || format(E'PASS T5 — Ludo victoire : gagnant reçoit %s Ar (commission %s pct)\n', v_net, v_cpct);

  UPDATE public.profiles SET balance_ar=0 WHERE id IN (v_p1,v_p2);
  INSERT INTO public.chess_games(host_id,white_id,black_id,stake,pot,status,mode)
    VALUES (v_p1,v_p1,v_p2,500,1000,'playing','stake') RETURNING id, commission_pct INTO v_game, v_cpct;
  PERFORM public._chess_payout(v_game, v_p1, false);
  SELECT balance_ar INTO v_bal FROM public.profiles WHERE id=v_p1;
  v_net := 1000 * (100 - v_cpct) / 100.0;
  IF v_bal<>v_net THEN RAISE EXCEPTION 'FAIL T6: %', v_bal; END IF;
  v_report := v_report || format(E'PASS T6 — Échecs victoire : gagnant reçoit %s Ar\n', v_net);

  UPDATE public.profiles SET balance_ar=0 WHERE id IN (v_p1,v_p2);
  INSERT INTO public.chess_games(host_id,white_id,black_id,stake,pot,status,mode)
    VALUES (v_p1,v_p1,v_p2,500,1000,'playing','stake') RETURNING id, commission_pct INTO v_game, v_cpct;
  PERFORM public._chess_payout(v_game, NULL, true);
  SELECT balance_ar INTO v_bal FROM public.profiles WHERE id=v_p1;
  SELECT balance_ar INTO v_bal2 FROM public.profiles WHERE id=v_p2;
  v_net := 1000 * (100 - v_cpct) / 100.0 / 2;
  IF v_bal<>v_net OR v_bal2<>v_net THEN RAISE EXCEPTION 'FAIL T7: % / %', v_bal, v_bal2; END IF;
  v_report := v_report || format(E'PASS T7 — Échecs nul : chaque joueur reçoit %s Ar\n', v_net);

  UPDATE public.profiles SET balance_ar=0 WHERE id IN (v_p1,v_p2);
  INSERT INTO public.domino_games(host_id,max_players,stake,pot,status,mode,state)
    VALUES (v_p1,2,1500,3000,'playing','classic','{}'::jsonb) RETURNING id, commission_pct INTO v_game, v_cpct;
  INSERT INTO public.domino_participants(game_id,user_id,slot,display_name,is_bot)
    VALUES (v_game,v_p1,0,'Joueur 1',false),(v_game,v_p2,1,'Joueur 2',false);
  PERFORM public._domino_finalize(v_game, 0);
  SELECT balance_ar INTO v_bal FROM public.profiles WHERE id=v_p1;
  v_net := 3000 * (100 - v_cpct) / 100;
  IF v_bal<>v_net THEN RAISE EXCEPTION 'FAIL T8: %', v_bal; END IF;
  v_report := v_report || format(E'PASS T8 — Domino victoire : gagnant reçoit %s Ar\n', v_net);

  INSERT INTO public.ludo_games(host_id,max_players,stake,pot,status,mode,commission_pct)
    VALUES (v_p1,2,0,0,'open','classic',999) RETURNING commission_pct INTO v_cpct;
  IF v_cpct <> public.get_game_commission('ludo') THEN
    RAISE EXCEPTION 'FAIL T9: % au lieu de %', v_cpct, public.get_game_commission('ludo');
  END IF;
  v_report := v_report || E'PASS T9 — Trigger écrase la commission client par le réglage serveur\n';

  PERFORM public._finance_tests_cleanup(v_ids);
  PERFORM set_config('request.jwt.claim.sub', COALESCE(v_saved_uid,''), true);

  RETURN E'\n' || v_report || E'\n✅ Tous les tests finance passent.\n';

EXCEPTION WHEN OTHERS THEN
  BEGIN PERFORM public._finance_tests_cleanup(v_ids); EXCEPTION WHEN OTHERS THEN NULL; END;
  RAISE;
END
$function$
;

CREATE OR REPLACE FUNCTION public.send_game_invite(_recipient_id uuid, _slug text, _game_id uuid, _sender_name text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  sender uuid := auth.uid();
  who text;
  link_path text;
BEGIN
  IF sender IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF _recipient_id = sender THEN RAISE EXCEPTION 'Cannot invite yourself'; END IF;

  SELECT COALESCE(_sender_name, pseudo, email, 'Un joueur') INTO who
    FROM public.profiles WHERE id = sender;

  link_path := CASE _slug
    WHEN 'ludo'     THEN '/game/'     || _game_id::text
    WHEN 'domino'   THEN '/domino/'   || _game_id::text
    WHEN 'fanorona' THEN '/fanorona/' || _game_id::text
    WHEN 'chess'    THEN '/chess/'    || _game_id::text
    WHEN 'rami'     THEN '/rami/'     || _game_id::text
    WHEN 'poker'    THEN '/poker/'    || _game_id::text
    ELSE '/jeux'
  END;

  INSERT INTO public.notifications (user_id, kind, type, title, body, link, ref_id)
  VALUES (
    _recipient_id,
    'game_invite',
    'game_invite',
    '🎮 Invitation à jouer',
    who || ' t''invite à une partie de ' || _slug,
    link_path,
    _game_id
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.spectate_join(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_max int; v_count int; v_enabled boolean;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'auth'; END IF;
  SELECT live_enabled, max_spectators INTO v_enabled, v_max FROM public.app_settings WHERE id=1;
  IF NOT COALESCE(v_enabled,true) THEN RAISE EXCEPTION 'LIVE désactivé'; END IF;
  SELECT count(*) INTO v_count FROM public.game_spectators WHERE game_id=_game_id;
  IF v_count >= COALESCE(v_max,50) THEN RAISE EXCEPTION 'LIVE complet'; END IF;
  INSERT INTO public.game_spectators(game_id,user_id) VALUES(_game_id, auth.uid()) ON CONFLICT DO NOTHING;
END $function$
;

-- ═══════════ 0007_functions_12.sql ═══════════
-- 0007_functions_12.sql
-- Fonctions et procédures (12/12)

CREATE OR REPLACE FUNCTION public.spectate_leave(_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  DELETE FROM public.game_spectators WHERE game_id=_game_id AND user_id=auth.uid();
END $function$
;

CREATE OR REPLACE FUNCTION public.submit_bug_report(_category text, _message text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid UUID := auth.uid(); v_id UUID;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF length(trim(_message)) < 5 THEN RAISE EXCEPTION 'Message trop court'; END IF;
  INSERT INTO public.bug_reports(user_id, category, message)
  VALUES (v_uid, COALESCE(NULLIF(trim(_category),''), 'general'), trim(_message))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.super_player_set_dice(_game_id uuid, _dice integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_slot int;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  IF _dice IS NOT NULL AND (_dice<1 OR _dice>6) THEN RAISE EXCEPTION 'dé invalide'; END IF;
  SELECT slot INTO v_slot FROM public.ludo_participants WHERE game_id=_game_id AND user_id=auth.uid();
  IF v_slot IS NULL THEN RAISE EXCEPTION 'Non participant'; END IF;
  UPDATE public.ludo_games SET dice_override = jsonb_set(COALESCE(dice_override,'{}'::jsonb), ARRAY[v_slot::text],
    CASE WHEN _dice IS NULL THEN 'null'::jsonb ELSE to_jsonb(_dice) END)
    WHERE id=_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.super_player_set_dice(_game_id uuid, _slot integer, _value integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  IF _value NOT BETWEEN 1 AND 6 THEN RAISE EXCEPTION 'valeur invalide'; END IF;
  UPDATE public.ludo_games
    SET dice_override = COALESCE(dice_override,'{}'::jsonb) || jsonb_build_object(_slot::text, _value)
    WHERE id=_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.sync_profile_is_admin()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid;
BEGIN
  v_uid := COALESCE(NEW.user_id, OLD.user_id);
  UPDATE public.profiles
    SET is_admin = EXISTS (SELECT 1 FROM public.user_roles r WHERE r.user_id = v_uid AND r.role = 'admin')
    WHERE id = v_uid;
  RETURN COALESCE(NEW, OLD);
END $function$
;

CREATE OR REPLACE FUNCTION public.tick_all_games()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public._auto_resume_paused_games();
  PERFORM public._auto_cancel_open_games();
  PERFORM public._auto_advance_overdue_turns();
END $function$
;

CREATE OR REPLACE FUNCTION public.toggle_spectator_chat(_game_id uuid, _enabled boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.ludo_participants WHERE game_id=_game_id AND user_id=auth.uid()) THEN
    RAISE EXCEPTION 'Non joueur';
  END IF;
  UPDATE public.ludo_games SET spectator_chat_enabled=_enabled WHERE id=_game_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.touch_announcements_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.touch_game_configs()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$function$
;

CREATE OR REPLACE FUNCTION public.tournament_engine(_tid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  t public.tournaments%ROWTYPE;
  m record; g record; v_win uuid; v_slot int; v_busy uuid[]; v_live int; v_cap int;
  v_pool record; v_next uuid[]; v_losers uuid[]; v_ready int; v_total int;
BEGIN
  SELECT * INTO t FROM public.tournaments WHERE id = _tid FOR UPDATE;
  IF t.id IS NULL OR t.status <> 'running' THEN RETURN; END IF;

  FOR m IN SELECT * FROM public.tournament_matches
            WHERE tournament_id = _tid AND status = 'running' AND game_id IS NOT NULL LOOP
    v_win := NULL;
    IF t.game_slug = 'ludo' THEN
      SELECT status::text AS st, winner_id INTO g FROM public.ludo_games WHERE id = m.game_id;
    ELSE
      SELECT status::text AS st, winner_id INTO g FROM public.domino_games WHERE id = m.game_id;
    END IF;
    CONTINUE WHEN g IS NULL;

    IF g.st = 'finished' THEN
      IF t.game_slug = 'ludo' THEN
        SELECT slot INTO v_slot FROM public.ludo_participants
         WHERE game_id = m.game_id
           AND ((g.winner_id IS NOT NULL AND user_id = g.winner_id) OR (g.winner_id IS NULL AND finish_rank = 1))
         LIMIT 1;
      ELSE
        SELECT slot INTO v_slot FROM public.domino_participants
         WHERE game_id = m.game_id
           AND ((g.winner_id IS NOT NULL AND user_id = g.winner_id) OR (g.winner_id IS NULL AND is_bot))
         LIMIT 1;
      END IF;
      v_win := m.entrant_ids[COALESCE(v_slot,0) + 1];
      PERFORM public._t_match_finish(m.id, v_win);

    ELSIF g.st = 'cancelled' THEN
      UPDATE public.tournament_matches SET status = 'scheduled', game_id = NULL, started_at = NULL, deadline_at = NULL
       WHERE id = m.id;

    ELSIF g.st = 'open' THEN
      IF t.game_slug = 'ludo' THEN
        SELECT count(*), count(*) FILTER (WHERE ready OR is_bot) INTO v_total, v_ready
          FROM public.ludo_participants WHERE game_id = m.game_id;
        IF v_total > 1 AND v_ready = v_total THEN
          UPDATE public.ludo_games SET status = 'playing', started_at = now(),
                 state = public._ludo_init_state(v_total) WHERE id = m.game_id AND status = 'open';
        END IF;
      ELSE
        SELECT count(*), count(*) FILTER (WHERE ready OR is_bot) INTO v_total, v_ready
          FROM public.domino_participants WHERE game_id = m.game_id;
        IF v_total > 1 AND v_ready = v_total THEN
          PERFORM public._domino_start(m.game_id);
        END IF;
      END IF;

      IF m.deadline_at < now() THEN
        IF t.game_slug = 'ludo' THEN
          SELECT slot INTO v_slot FROM public.ludo_participants
           WHERE game_id = m.game_id AND (ready OR is_bot) ORDER BY slot LIMIT 1;
          UPDATE public.ludo_games SET status = 'cancelled', finished_at = now() WHERE id = m.game_id;
        ELSE
          SELECT slot INTO v_slot FROM public.domino_participants
           WHERE game_id = m.game_id AND (ready OR is_bot) ORDER BY slot LIMIT 1;
          UPDATE public.domino_games SET status = 'cancelled', finished_at = now() WHERE id = m.game_id;
        END IF;
        PERFORM public._t_match_finish(m.id, m.entrant_ids[COALESCE(v_slot,0) + 1]);
      END IF;
    END IF;
  END LOOP;

  -- clôture des poules terminées : classement recalculé puis départage déterministe
  FOR v_pool IN SELECT p.* FROM public.tournament_pools p
                 WHERE p.tournament_id = _tid AND p.status = 'running'
                   AND NOT EXISTS (SELECT 1 FROM public.tournament_matches mm
                                    WHERE mm.pool_id = p.id AND mm.status IN ('scheduled','running')) LOOP
    PERFORM public._t_pool_recompute(v_pool.id);
    UPDATE public.tournament_pool_entrants pe SET qualified = true
     WHERE pe.pool_id = v_pool.id
       AND pe.entrant_id IN (
         SELECT r.entrant_id FROM public._t_pool_rank(v_pool.id) r
          WHERE r.pos <= (SELECT qualifiers_per_pool FROM public.tournaments WHERE id = _tid));
    UPDATE public.tournament_entrants e SET status = 'eliminated', eliminated_round = 1
      FROM public.tournament_pool_entrants pe
     WHERE pe.pool_id = v_pool.id AND pe.entrant_id = e.id AND NOT pe.qualified AND e.status = 'active';
    UPDATE public.tournament_pools SET status = 'finished' WHERE id = v_pool.id;
  END LOOP;

  IF NOT EXISTS (SELECT 1 FROM public.tournament_matches
                  WHERE tournament_id = _tid AND status IN ('scheduled','running')) THEN
    IF t.auto_advance THEN
      IF t.stage = 'pools' THEN
        SELECT array_agg(e.id ORDER BY random()) INTO v_next
          FROM public.tournament_entrants e WHERE e.tournament_id = _tid AND e.status = 'active';
        PERFORM public._t_build_round(_tid, 2, v_next);
      ELSIF t.stage = 'finals' THEN
        IF (SELECT count(*) FROM public.tournament_matches
                 WHERE tournament_id = _tid AND round = t.current_round AND phase = 'final') = 2
           AND NOT EXISTS (SELECT 1 FROM public.tournament_matches
                            WHERE tournament_id = _tid AND phase = 'third_place') THEN
          SELECT array_agg(x.eid) INTO v_losers FROM (
            SELECT unnest(mm.entrant_ids) eid, mm.winner_entrant_id w
              FROM public.tournament_matches mm
             WHERE mm.tournament_id = _tid AND mm.round = t.current_round AND mm.phase = 'final') x
           WHERE x.eid IS DISTINCT FROM x.w;
          IF array_length(v_losers,1) = 2 THEN
            INSERT INTO public.tournament_matches(tournament_id, phase, round, match_no, entrant_ids)
              VALUES (_tid, 'third_place', t.current_round + 1, 1, v_losers);
          END IF;
        END IF;

        -- vainqueurs du tour + joueurs restés actifs sans match (non appairés)
        SELECT array_agg(id) INTO v_next FROM (
          SELECT e.id
            FROM public.tournament_entrants e
           WHERE e.tournament_id = _tid AND e.status = 'active'
           ORDER BY e.created_at) s;

        IF COALESCE(array_length(v_next,1),0) <= 1 AND NOT EXISTS (
             SELECT 1 FROM public.tournament_matches
              WHERE tournament_id = _tid AND status IN ('scheduled','running')) THEN
          UPDATE public.tournaments SET champion_entrant_id = v_next[1] WHERE id = _tid;
          PERFORM public._t_finish(_tid);
          RETURN;
        ELSIF COALESCE(array_length(v_next,1),0) > 1 THEN
          PERFORM public._t_build_round(_tid, t.current_round + 1, v_next);
        END IF;
      END IF;
      SELECT * INTO t FROM public.tournaments WHERE id = _tid;
    END IF;
  END IF;

  -- lancement des matchs : maximum 8 simultanés
  v_cap := LEAST(COALESCE(t.max_concurrent_matches, 8), 8);
  SELECT count(*) INTO v_live FROM public.tournament_matches
   WHERE tournament_id = _tid AND status = 'running';
  SELECT COALESCE(array_agg(x), ARRAY[]::uuid[]) INTO v_busy FROM (
    SELECT unnest(entrant_ids) x FROM public.tournament_matches
     WHERE tournament_id = _tid AND status = 'running') s;

  FOR m IN SELECT * FROM public.tournament_matches
            WHERE tournament_id = _tid AND status = 'scheduled'
            ORDER BY round, match_no LOOP
    EXIT WHEN v_live >= v_cap;
    CONTINUE WHEN m.entrant_ids && v_busy;
    PERFORM public._t_launch_match(m.id);
    v_busy := v_busy || m.entrant_ids;
    v_live := v_live + 1;
  END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION public.tournament_engine_all()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE r record;
BEGIN
  FOR r IN SELECT id FROM public.tournaments WHERE status = 'running' LOOP
    BEGIN PERFORM public.tournament_engine(r.id); EXCEPTION WHEN OTHERS THEN NULL; END;
  END LOOP;
END $function$
;

CREATE OR REPLACE FUNCTION public.tournament_register(_tid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE t public.tournaments%ROWTYPE; v_uid uuid := auth.uid(); v_n int; v_name text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  SELECT * INTO t FROM public.tournaments WHERE id = _tid FOR UPDATE;
  IF t.id IS NULL OR t.status <> 'open' THEN RAISE EXCEPTION 'Inscriptions fermées'; END IF;
  IF EXISTS (SELECT 1 FROM public.tournament_entrants WHERE tournament_id = _tid AND user_id = v_uid) THEN
    RAISE EXCEPTION 'Déjà inscrit';
  END IF;
  SELECT count(*) INTO v_n FROM public.tournament_entrants WHERE tournament_id = _tid;
  IF v_n >= t.max_players THEN RAISE EXCEPTION 'Tournoi complet'; END IF;

  IF t.entry_fee_ar > 0 THEN
    PERFORM public.debit_user_balance(v_uid, t.entry_fee_ar, 'tournament_entry', _tid,
      'Inscription tournoi: ' || t.name, '{}'::jsonb);
    UPDATE public.tournaments SET prize_pool_ar = prize_pool_ar + t.entry_fee_ar WHERE id = _tid;
  END IF;

  SELECT COALESCE(pseudo, 'Joueur') INTO v_name FROM public.profiles WHERE id = v_uid;
  INSERT INTO public.tournament_entrants(tournament_id, user_id, display_name) VALUES (_tid, v_uid, v_name);
END $function$
;

CREATE OR REPLACE FUNCTION public.tournament_sim_report(_tid uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE t public.tournaments%ROWTYPE; v_issues text[] := ARRAY[]::text[]; r record; v int;
BEGIN
  SELECT * INTO t FROM public.tournaments WHERE id = _tid;
  IF t.id IS NULL THEN RETURN jsonb_build_object('error','tournoi introuvable'); END IF;

  -- 1. points de poule = 3*victoires + nuls, played cohérent
  FOR r IN
    SELECT pe.pool_id, pe.entrant_id, pe.points, pe.wins, pe.played,
           (SELECT count(*) FROM public.tournament_matches mm
             WHERE mm.pool_id = pe.pool_id AND mm.status='finished' AND pe.entrant_id = ANY(mm.entrant_ids)) AS real_played,
           (SELECT count(*) FROM public.tournament_matches mm
             WHERE mm.pool_id = pe.pool_id AND mm.status='finished' AND mm.winner_entrant_id = pe.entrant_id) AS real_wins,
           (SELECT count(*) FROM public.tournament_matches mm
             WHERE mm.pool_id = pe.pool_id AND mm.status='finished' AND mm.winner_entrant_id IS NULL
               AND pe.entrant_id = ANY(mm.entrant_ids)) AS real_draws
      FROM public.tournament_pool_entrants pe
      JOIN public.tournament_pools p ON p.id = pe.pool_id
     WHERE p.tournament_id = _tid
  LOOP
    IF r.played <> r.real_played THEN
      v_issues := v_issues || format('poule: matchs joués incohérents (%s)', r.entrant_id);
    END IF;
    IF r.wins <> r.real_wins THEN
      v_issues := v_issues || format('poule: victoires incohérentes (%s)', r.entrant_id);
    END IF;
    IF r.points <> (3 * r.real_wins + r.real_draws) THEN
      v_issues := v_issues || format('poule: points incohérents (%s)', r.entrant_id);
    END IF;
  END LOOP;

  -- 2. qualifiés par poule = qualifiers_per_pool
  FOR r IN SELECT p.id, p.label, p.status,
                  (SELECT count(*) FROM public.tournament_pool_entrants pe WHERE pe.pool_id = p.id AND pe.qualified) q
             FROM public.tournament_pools p WHERE p.tournament_id = _tid AND p.status = 'finished' LOOP
    IF r.q <> t.qualifiers_per_pool THEN
      v_issues := v_issues || format('%s: %s qualifiés au lieu de %s', r.label, r.q, t.qualifiers_per_pool);
    END IF;
  END LOOP;

  -- 3. bracket : aucun match sans vainqueur ni en attente une fois terminé
  IF t.status = 'finished' THEN
    SELECT count(*) INTO v FROM public.tournament_matches
     WHERE tournament_id = _tid AND status IN ('scheduled','running');
    IF v > 0 THEN v_issues := v_issues || format('%s match(s) non terminés', v); END IF;

    SELECT count(*) INTO v FROM public.tournament_matches
     WHERE tournament_id = _tid AND phase <> 'pool' AND status = 'finished' AND winner_entrant_id IS NULL;
    IF v > 0 THEN v_issues := v_issues || format('%s match(s) éliminatoires sans vainqueur', v); END IF;

    IF t.champion_entrant_id IS NULL THEN v_issues := v_issues || 'aucun champion désigné'; END IF;

    SELECT count(*) INTO v FROM public.tournament_entrants
     WHERE tournament_id = _tid AND final_rank IS NULL;
    IF v > 0 THEN v_issues := v_issues || format('%s joueur(s) sans classement final', v); END IF;

    SELECT count(*) INTO v FROM (
      SELECT final_rank FROM public.tournament_entrants
       WHERE tournament_id = _tid AND final_rank IS NOT NULL
       GROUP BY final_rank HAVING count(*) > 1) s;
    IF v > 0 THEN v_issues := v_issues || format('%s rang(s) final(aux) en doublon', v); END IF;

    SELECT count(*) INTO v FROM public.tournament_entrants
     WHERE tournament_id = _tid AND status = 'active' AND id IS DISTINCT FROM t.champion_entrant_id;
    IF v > 0 THEN v_issues := v_issues || format('%s joueur(s) encore actifs', v); END IF;
  END IF;

  -- 4. un joueur ne doit jamais être dans 2 matchs simultanés
  SELECT count(*) INTO v FROM (
    SELECT unnest(entrant_ids) eid FROM public.tournament_matches
     WHERE tournament_id = _tid AND status = 'running'
     GROUP BY 1 HAVING count(*) > 1) s;
  IF v > 0 THEN v_issues := v_issues || format('%s joueur(s) dans plusieurs matchs à la fois', v); END IF;

  RETURN jsonb_build_object(
    'tournament_id', _tid,
    'name', t.name,
    'game', t.game_slug,
    'format', t.format,
    'status', t.status,
    'stage', t.stage,
    'rounds', t.current_round,
    'entrants', (SELECT count(*) FROM public.tournament_entrants WHERE tournament_id = _tid),
    'matches', (SELECT count(*) FROM public.tournament_matches WHERE tournament_id = _tid),
    'pools', (SELECT count(*) FROM public.tournament_pools WHERE tournament_id = _tid),
    'champion', (SELECT display_name FROM public.tournament_entrants WHERE id = t.champion_entrant_id),
    'podium', COALESCE((SELECT jsonb_agg(jsonb_build_object('rank', final_rank, 'name', display_name) ORDER BY final_rank)
                          FROM public.tournament_entrants
                         WHERE tournament_id = _tid AND final_rank IS NOT NULL AND final_rank <= 3), '[]'::jsonb),
    'standings', COALESCE((SELECT jsonb_agg(jsonb_build_object(
                              'pool', p.label,
                              'rows', (SELECT jsonb_agg(jsonb_build_object(
                                          'name', e.display_name, 'pts', pe.points, 'v', pe.wins,
                                          'j', pe.played, 'qualifie', pe.qualified) ORDER BY pe.points DESC, pe.wins DESC)
                                         FROM public.tournament_pool_entrants pe
                                         JOIN public.tournament_entrants e ON e.id = pe.entrant_id
                                        WHERE pe.pool_id = p.id)) ORDER BY p.label)
                            FROM public.tournament_pools p WHERE p.tournament_id = _tid), '[]'::jsonb),
    'ok', array_length(v_issues,1) IS NULL,
    'issues', to_jsonb(v_issues)
  );
END $function$
;

CREATE OR REPLACE FUNCTION public.tournament_state(_tid uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT jsonb_build_object(
    'tournament', to_jsonb(t),
    'entrants', COALESCE((SELECT jsonb_agg(to_jsonb(e) ORDER BY e.created_at)
                          FROM public.tournament_entrants e WHERE e.tournament_id = t.id), '[]'::jsonb),
    'pools', COALESCE((SELECT jsonb_agg(jsonb_build_object(
                          'pool', to_jsonb(p),
                          'players', COALESCE((SELECT jsonb_agg(to_jsonb(pe) ORDER BY pe.points DESC, pe.wins DESC)
                                               FROM public.tournament_pool_entrants pe WHERE pe.pool_id = p.id), '[]'::jsonb))
                          ORDER BY p.label)
                       FROM public.tournament_pools p WHERE p.tournament_id = t.id), '[]'::jsonb),
    'matches', COALESCE((SELECT jsonb_agg(to_jsonb(m) ORDER BY m.round, m.match_no)
                         FROM public.tournament_matches m WHERE m.tournament_id = t.id), '[]'::jsonb)
  ) FROM public.tournaments t WHERE t.id = _tid;
$function$
;

CREATE OR REPLACE FUNCTION public.tournament_unregister(_tid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE t public.tournaments%ROWTYPE; v_uid uuid := auth.uid();
BEGIN
  SELECT * INTO t FROM public.tournaments WHERE id = _tid FOR UPDATE;
  IF t.status <> 'open' THEN RAISE EXCEPTION 'Tournoi déjà lancé'; END IF;
  DELETE FROM public.tournament_entrants WHERE tournament_id = _tid AND user_id = v_uid;
  IF FOUND AND t.entry_fee_ar > 0 THEN
    PERFORM public.credit_user_balance(v_uid, t.entry_fee_ar, 'tournament_refund', _tid,
      'Désinscription tournoi: ' || t.name, '{}'::jsonb);
    UPDATE public.tournaments SET prize_pool_ar = GREATEST(0, prize_pool_ar - t.entry_fee_ar) WHERE id = _tid;
  END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.update_game_state(_game_id uuid, _state jsonb, _current_turn integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ludo_participants WHERE game_id=_game_id AND user_id=v_uid)
     AND NOT EXISTS (SELECT 1 FROM public.ludo_games WHERE id=_game_id AND host_id=v_uid) THEN
    RAISE EXCEPTION 'Non participant';
  END IF;
  UPDATE public.ludo_games SET state = _state, current_turn = _current_turn
   WHERE id = _game_id AND status = 'playing';
END $function$
;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $function$
;

CREATE OR REPLACE FUNCTION public.verify_phone_code(_code text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_hash text; v_expected text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth'; END IF;
  SELECT phone_verification_code_hash INTO v_hash FROM public.profiles WHERE id = v_uid;
  IF v_hash IS NULL THEN RETURN false; END IF;
  v_expected := encode(extensions.digest(_code || v_uid::text, 'sha256'), 'hex');
  IF v_hash = v_expected THEN
    UPDATE public.profiles
      SET phone_verified = true,
          phone_verification_code = NULL,
          phone_verification_code_hash = NULL
      WHERE id = v_uid;
    RETURN true;
  END IF;
  RETURN false;
END $function$
;

CREATE OR REPLACE FUNCTION public.weekly_top_winners(_limit integer DEFAULT 10)
 RETURNS TABLE(user_id uuid, pseudo text, avatar_url text, wins bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  WITH wins AS (
    SELECT g.winner_id AS uid, COALESCE(NULLIF(trim(pp.display_name),''), p.pseudo, 'Joueur') AS name
      FROM ludo_games g
      JOIN ludo_participants pp ON pp.game_id=g.id AND pp.user_id=g.winner_id
      LEFT JOIN profiles p ON p.id=g.winner_id
      WHERE g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at, g.created_at) >= now() - interval '7 days'
    UNION ALL
    SELECT g.winner_id, COALESCE(NULLIF(trim(pp.display_name),''), p.pseudo, 'Joueur')
      FROM domino_games g
      JOIN domino_participants pp ON pp.game_id=g.id AND pp.user_id=g.winner_id
      LEFT JOIN profiles p ON p.id=g.winner_id
      WHERE g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at, g.created_at) >= now() - interval '7 days'
    UNION ALL
    SELECT g.winner_id, COALESCE(NULLIF(trim(pp.display_name),''), p.pseudo, 'Joueur')
      FROM fanorona_games g
      JOIN fanorona_participants pp ON pp.game_id=g.id AND pp.user_id=g.winner_id
      LEFT JOIN profiles p ON p.id=g.winner_id
      WHERE g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at, g.created_at) >= now() - interval '7 days'
    UNION ALL
    SELECT g.winner_id, COALESCE(NULLIF(trim(pp.display_name),''), p.pseudo, 'Joueur')
      FROM rami_games g
      JOIN rami_participants pp ON pp.game_id=g.id AND pp.user_id=g.winner_id
      LEFT JOIN profiles p ON p.id=g.winner_id
      WHERE g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at, g.created_at) >= now() - interval '7 days'
    UNION ALL
    SELECT g.winner_id, COALESCE(p.pseudo, 'Joueur')
      FROM chess_games g
      LEFT JOIN profiles p ON p.id=g.winner_id
      WHERE g.status='finished' AND g.winner_id IS NOT NULL
        AND COALESCE(g.finished_at, g.created_at) >= now() - interval '7 days'
  ),
  filtered AS (
    SELECT w.uid, w.name FROM wins w
    WHERE NOT public.has_role(w.uid, 'admin'::public.app_role)
  ),
  agg AS (
    SELECT name, (array_agg(uid))[1] AS uid, count(*)::bigint AS wins
    FROM filtered
    GROUP BY name
  )
  SELECT a.uid, a.name, p.avatar_url, a.wins
  FROM agg a LEFT JOIN profiles p ON p.id = a.uid
  ORDER BY a.wins DESC, a.name ASC
  LIMIT _limit;
$function$
;

-- ═══════════ 0008_views.sql ═══════════
-- 0008_views.sql
-- Vues et vues matérialisées

CREATE OR REPLACE VIEW public.v_finance_daily AS
 SELECT (date_trunc('day'::text, created_at))::date AS day,
    sum(
        CASE
            WHEN (type = 'deposit'::text) THEN amount
            ELSE (0)::numeric
        END) AS deposits,
    sum(
        CASE
            WHEN (type = 'withdraw'::text) THEN (- amount)
            ELSE (0)::numeric
        END) AS withdrawals,
    sum(
        CASE
            WHEN (type = 'stake'::text) THEN (- amount)
            ELSE (0)::numeric
        END) AS stakes,
    sum(
        CASE
            WHEN (type = 'payout'::text) THEN amount
            ELSE (0)::numeric
        END) AS payouts,
    sum(
        CASE
            WHEN (type = 'refund'::text) THEN amount
            ELSE (0)::numeric
        END) AS refunds,
    sum(
        CASE
            WHEN (type = 'commission'::text) THEN (- amount)
            ELSE (0)::numeric
        END) AS commissions,
    sum(
        CASE
            WHEN (type = ANY (ARRAY['bonus'::text, 'referral'::text, 'admin_adjust'::text])) THEN amount
            ELSE (0)::numeric
        END) AS bonuses_adjustments,
    count(*) AS tx_count
   FROM transactions
  WHERE (created_at >= (now() - '90 days'::interval))
  GROUP BY ((date_trunc('day'::text, created_at))::date)
  ORDER BY ((date_trunc('day'::text, created_at))::date) DESC;

CREATE OR REPLACE VIEW public.v_player_stats AS
 SELECT id,
    pseudo,
    avatar_url,
    COALESCE(total_wins, 0) AS total_wins,
    COALESCE(total_games, 0) AS total_games,
    COALESCE(player_level, 1) AS player_level,
    COALESCE(daily_streak, 0) AS daily_streak
   FROM profiles p
  WHERE ((is_banned = false) OR (is_banned IS NULL));

CREATE OR REPLACE VIEW public.v_referral_stats AS
 SELECT p.id AS referrer_id,
    p.referral_code,
    count(DISTINCT ref.id) AS total_referrals,
    count(DISTINCT ref.id) FILTER (WHERE ref.referral_unlocked) AS active_referrals,
    COALESCE(sum(re.reward_amount), (0)::numeric) AS total_earned_ar,
    count(DISTINCT re.id) FILTER (WHERE (re.event_type = 'first_deposit'::text)) AS paid_events,
        CASE
            WHEN (count(DISTINCT ref.id) FILTER (WHERE ref.referral_unlocked) >= ( SELECT referral_settings.tier_diamond_min
               FROM referral_settings
              WHERE (referral_settings.id = 1))) THEN 'diamond'::text
            WHEN (count(DISTINCT ref.id) FILTER (WHERE ref.referral_unlocked) >= ( SELECT referral_settings.tier_gold_min
               FROM referral_settings
              WHERE (referral_settings.id = 1))) THEN 'gold'::text
            WHEN (count(DISTINCT ref.id) FILTER (WHERE ref.referral_unlocked) >= ( SELECT referral_settings.tier_silver_min
               FROM referral_settings
              WHERE (referral_settings.id = 1))) THEN 'silver'::text
            ELSE 'bronze'::text
        END AS tier
   FROM ((profiles p
     LEFT JOIN profiles ref ON ((ref.referred_by = p.id)))
     LEFT JOIN referral_events re ON ((re.referrer_id = p.id)))
  GROUP BY p.id, p.referral_code;

-- ═══════════ 0009_triggers.sql ═══════════
-- 0009_triggers.sql
-- Déclencheurs (triggers)

DROP TRIGGER IF EXISTS touch_announcements_updated_at ON public.announcements; CREATE TRIGGER touch_announcements_updated_at BEFORE UPDATE ON public.announcements FOR EACH ROW EXECUTE FUNCTION touch_announcements_updated_at();
DROP TRIGGER IF EXISTS trg_app_settings_validate ON public.app_settings; CREATE TRIGGER trg_app_settings_validate BEFORE INSERT OR UPDATE ON public.app_settings FOR EACH ROW EXECUTE FUNCTION _app_settings_validate_trigger();
DROP TRIGGER IF EXISTS trg_apply_commission ON public.billiard_games; CREATE TRIGGER trg_apply_commission BEFORE INSERT ON public.billiard_games FOR EACH ROW EXECUTE FUNCTION _apply_game_commission('billiard');
DROP TRIGGER IF EXISTS trg_chat_snapshot_sender ON public.chat_messages; CREATE TRIGGER trg_chat_snapshot_sender BEFORE INSERT ON public.chat_messages FOR EACH ROW EXECUTE FUNCTION _chat_snapshot_sender();
DROP TRIGGER IF EXISTS trg_apply_commission ON public.chess_games; CREATE TRIGGER trg_apply_commission BEFORE INSERT ON public.chess_games FOR EACH ROW EXECUTE FUNCTION _apply_game_commission('chess');
DROP TRIGGER IF EXISTS trg_chess_global_deadline ON public.chess_games; CREATE TRIGGER trg_chess_global_deadline BEFORE UPDATE ON public.chess_games FOR EACH ROW EXECUTE FUNCTION _set_chess_global_deadline();
DROP TRIGGER IF EXISTS trg_first_game_chess ON public.chess_games; CREATE TRIGGER trg_first_game_chess AFTER UPDATE ON public.chess_games FOR EACH ROW EXECUTE FUNCTION _mark_first_game('chess');
DROP TRIGGER IF EXISTS trg_house_on_finish ON public.chess_games; CREATE TRIGGER trg_house_on_finish AFTER UPDATE OF status ON public.chess_games FOR EACH ROW EXECUTE FUNCTION _log_house_on_finish('chess');
DROP TRIGGER IF EXISTS trg_player_stats_chess ON public.chess_games; CREATE TRIGGER trg_player_stats_chess AFTER UPDATE OF status ON public.chess_games FOR EACH ROW EXECUTE FUNCTION _update_player_stats_on_win();
DROP TRIGGER IF EXISTS trg_skip_noop_chess ON public.chess_games; CREATE TRIGGER trg_skip_noop_chess BEFORE UPDATE ON public.chess_games FOR EACH ROW EXECUTE FUNCTION _skip_noop_update();
DROP TRIGGER IF EXISTS trg_notify_deposit_created ON public.deposits; CREATE TRIGGER trg_notify_deposit_created AFTER INSERT ON public.deposits FOR EACH ROW EXECUTE FUNCTION _notify_deposit_created();
DROP TRIGGER IF EXISTS trg_referral_on_deposit ON public.deposits; CREATE TRIGGER trg_referral_on_deposit AFTER UPDATE ON public.deposits FOR EACH ROW EXECUTE FUNCTION _referral_on_deposit();
DROP TRIGGER IF EXISTS domino_apply_turn_timer ON public.domino_games; CREATE TRIGGER domino_apply_turn_timer BEFORE INSERT OR UPDATE OF turn_deadline ON public.domino_games FOR EACH ROW EXECUTE FUNCTION _domino_apply_turn_timer();
DROP TRIGGER IF EXISTS trg_apply_commission ON public.domino_games; CREATE TRIGGER trg_apply_commission BEFORE INSERT ON public.domino_games FOR EACH ROW EXECUTE FUNCTION _apply_game_commission('domino');
DROP TRIGGER IF EXISTS trg_domino_deadline ON public.domino_games; CREATE TRIGGER trg_domino_deadline BEFORE INSERT OR UPDATE ON public.domino_games FOR EACH ROW EXECUTE FUNCTION _set_turn_deadline();
DROP TRIGGER IF EXISTS trg_first_game_domino ON public.domino_games; CREATE TRIGGER trg_first_game_domino AFTER UPDATE ON public.domino_games FOR EACH ROW EXECUTE FUNCTION _mark_first_game('domino');
DROP TRIGGER IF EXISTS trg_house_on_finish ON public.domino_games; CREATE TRIGGER trg_house_on_finish AFTER UPDATE OF status ON public.domino_games FOR EACH ROW EXECUTE FUNCTION _log_house_on_finish('domino');
DROP TRIGGER IF EXISTS trg_player_stats_domino ON public.domino_games; CREATE TRIGGER trg_player_stats_domino AFTER UPDATE OF status ON public.domino_games FOR EACH ROW EXECUTE FUNCTION _update_player_stats_on_win();
DROP TRIGGER IF EXISTS trg_skip_noop_domino ON public.domino_games; CREATE TRIGGER trg_skip_noop_domino BEFORE UPDATE ON public.domino_games FOR EACH ROW EXECUTE FUNCTION _skip_noop_update();
DROP TRIGGER IF EXISTS trg_domino_participant_end_check ON public.domino_participants; CREATE TRIGGER trg_domino_participant_end_check AFTER UPDATE ON public.domino_participants FOR EACH ROW EXECUTE FUNCTION _trg_domino_participant_end_check();
DROP TRIGGER IF EXISTS trg_apply_commission ON public.fanorona_games; CREATE TRIGGER trg_apply_commission BEFORE INSERT ON public.fanorona_games FOR EACH ROW EXECUTE FUNCTION _apply_game_commission('fanorona');
DROP TRIGGER IF EXISTS trg_fanorona_deadline ON public.fanorona_games; CREATE TRIGGER trg_fanorona_deadline BEFORE INSERT OR UPDATE ON public.fanorona_games FOR EACH ROW EXECUTE FUNCTION _set_turn_deadline();
DROP TRIGGER IF EXISTS trg_fanorona_global_deadline ON public.fanorona_games; CREATE TRIGGER trg_fanorona_global_deadline BEFORE UPDATE ON public.fanorona_games FOR EACH ROW EXECUTE FUNCTION _set_fanorona_global_deadline();
DROP TRIGGER IF EXISTS trg_first_game_fanorona ON public.fanorona_games; CREATE TRIGGER trg_first_game_fanorona AFTER UPDATE ON public.fanorona_games FOR EACH ROW EXECUTE FUNCTION _mark_first_game('fanorona');
DROP TRIGGER IF EXISTS trg_house_on_finish ON public.fanorona_games; CREATE TRIGGER trg_house_on_finish AFTER UPDATE OF status ON public.fanorona_games FOR EACH ROW EXECUTE FUNCTION _log_house_on_finish('fanorona');
DROP TRIGGER IF EXISTS trg_player_stats_fanorona ON public.fanorona_games; CREATE TRIGGER trg_player_stats_fanorona AFTER UPDATE OF status ON public.fanorona_games FOR EACH ROW EXECUTE FUNCTION _update_player_stats_on_win();
DROP TRIGGER IF EXISTS trg_fanorona_participant_end_check ON public.fanorona_participants; CREATE TRIGGER trg_fanorona_participant_end_check AFTER UPDATE ON public.fanorona_participants FOR EACH ROW EXECUTE FUNCTION _trg_fanorona_participant_end_check();
DROP TRIGGER IF EXISTS friendships_updated_at ON public.friendships; CREATE TRIGGER friendships_updated_at BEFORE UPDATE ON public.friendships FOR EACH ROW EXECUTE FUNCTION friendships_touch_updated_at();
DROP TRIGGER IF EXISTS trg_touch_game_configs ON public.game_configs; CREATE TRIGGER trg_touch_game_configs BEFORE UPDATE ON public.game_configs FOR EACH ROW EXECUTE FUNCTION touch_game_configs();
DROP TRIGGER IF EXISTS gi_updated_at ON public.game_invitations; CREATE TRIGGER gi_updated_at BEFORE UPDATE ON public.game_invitations FOR EACH ROW EXECUTE FUNCTION gi_touch_updated_at();
DROP TRIGGER IF EXISTS trg_apply_commission ON public.ludo_games; CREATE TRIGGER trg_apply_commission BEFORE INSERT ON public.ludo_games FOR EACH ROW EXECUTE FUNCTION _apply_game_commission('ludo');
DROP TRIGGER IF EXISTS trg_first_game_ludo ON public.ludo_games; CREATE TRIGGER trg_first_game_ludo AFTER UPDATE ON public.ludo_games FOR EACH ROW EXECUTE FUNCTION _mark_first_game('ludo');
DROP TRIGGER IF EXISTS trg_house_on_finish ON public.ludo_games; CREATE TRIGGER trg_house_on_finish AFTER UPDATE OF status ON public.ludo_games FOR EACH ROW EXECUTE FUNCTION _log_house_on_finish('ludo');
DROP TRIGGER IF EXISTS trg_ludo_ready_deadline ON public.ludo_games; CREATE TRIGGER trg_ludo_ready_deadline BEFORE INSERT ON public.ludo_games FOR EACH ROW EXECUTE FUNCTION _ludo_set_ready_deadline();
DROP TRIGGER IF EXISTS trg_ludo_sync_turn_snapshot ON public.ludo_games; CREATE TRIGGER trg_ludo_sync_turn_snapshot BEFORE INSERT OR UPDATE OF state ON public.ludo_games FOR EACH ROW EXECUTE FUNCTION _ludo_sync_turn_snapshot();
DROP TRIGGER IF EXISTS trg_skip_noop_ludo ON public.ludo_games; CREATE TRIGGER trg_skip_noop_ludo BEFORE UPDATE ON public.ludo_games FOR EACH ROW EXECUTE FUNCTION _skip_noop_update();
DROP TRIGGER IF EXISTS trg_tourn_launch_after_finish ON public.ludo_games; CREATE TRIGGER trg_tourn_launch_after_finish AFTER UPDATE OF status ON public.ludo_games FOR EACH ROW EXECUTE FUNCTION _tourn_launch_after_finish();
DROP TRIGGER IF EXISTS trg_ludo_participant_end_check ON public.ludo_participants; CREATE TRIGGER trg_ludo_participant_end_check AFTER UPDATE ON public.ludo_participants FOR EACH ROW EXECUTE FUNCTION _trg_ludo_participant_end_check();
DROP TRIGGER IF EXISTS prr_touch ON public.password_reset_requests; CREATE TRIGGER prr_touch BEFORE UPDATE ON public.password_reset_requests FOR EACH ROW EXECUTE FUNCTION _prr_touch();
DROP TRIGGER IF EXISTS poker_apply_turn_timer ON public.poker_games; CREATE TRIGGER poker_apply_turn_timer BEFORE UPDATE OF turn_deadline ON public.poker_games FOR EACH ROW EXECUTE FUNCTION _poker_apply_turn_timer();
DROP TRIGGER IF EXISTS trg_apply_commission ON public.poker_games; CREATE TRIGGER trg_apply_commission BEFORE INSERT ON public.poker_games FOR EACH ROW EXECUTE FUNCTION _apply_game_commission('poker');
DROP TRIGGER IF EXISTS trg_house_on_finish ON public.poker_games; CREATE TRIGGER trg_house_on_finish AFTER UPDATE OF status ON public.poker_games FOR EACH ROW EXECUTE FUNCTION _log_house_on_finish('poker');
DROP TRIGGER IF EXISTS trg_skip_noop_poker ON public.poker_games; CREATE TRIGGER trg_skip_noop_poker BEFORE UPDATE ON public.poker_games FOR EACH ROW EXECUTE FUNCTION _skip_noop_update();
DROP TRIGGER IF EXISTS trg_balance_audit ON public.profiles; CREATE TRIGGER trg_balance_audit AFTER UPDATE OF balance_ar ON public.profiles FOR EACH ROW EXECUTE FUNCTION _trg_balance_audit();
DROP TRIGGER IF EXISTS trg_check_achievements ON public.profiles; CREATE TRIGGER trg_check_achievements AFTER UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION _trg_check_achievements_on_win();
DROP TRIGGER IF EXISTS trg_guard_balance_non_negative ON public.profiles; CREATE TRIGGER trg_guard_balance_non_negative BEFORE UPDATE OF balance_ar ON public.profiles FOR EACH ROW WHEN ((new.balance_ar IS DISTINCT FROM old.balance_ar)) EXECUTE FUNCTION _guard_balance_non_negative();
DROP TRIGGER IF EXISTS trg_no_bot_money ON public.profiles; CREATE TRIGGER trg_no_bot_money BEFORE UPDATE OF balance_ar ON public.profiles FOR EACH ROW EXECUTE FUNCTION _trg_no_bot_money();
DROP TRIGGER IF EXISTS trg_referral_on_phone ON public.profiles; CREATE TRIGGER trg_referral_on_phone AFTER UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION _referral_on_phone_verified();
DROP TRIGGER IF EXISTS trg_referral_signup ON public.profiles; CREATE TRIGGER trg_referral_signup AFTER INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION _referral_on_signup();
DROP TRIGGER IF EXISTS trg_sync_banned_flags ON public.profiles; CREATE TRIGGER trg_sync_banned_flags BEFORE INSERT OR UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION _sync_banned_flags();
DROP TRIGGER IF EXISTS trg_apply_commission ON public.rami_games; CREATE TRIGGER trg_apply_commission BEFORE INSERT ON public.rami_games FOR EACH ROW EXECUTE FUNCTION _apply_game_commission('rami');
DROP TRIGGER IF EXISTS trg_first_game_rami ON public.rami_games; CREATE TRIGGER trg_first_game_rami AFTER UPDATE ON public.rami_games FOR EACH ROW EXECUTE FUNCTION _mark_first_game('rami');
DROP TRIGGER IF EXISTS trg_house_on_finish ON public.rami_games; CREATE TRIGGER trg_house_on_finish AFTER UPDATE OF status ON public.rami_games FOR EACH ROW EXECUTE FUNCTION _log_house_on_finish('rami');
DROP TRIGGER IF EXISTS trg_skip_noop_rami ON public.rami_games; CREATE TRIGGER trg_skip_noop_rami BEFORE UPDATE ON public.rami_games FOR EACH ROW EXECUTE FUNCTION _skip_noop_update();
DROP TRIGGER IF EXISTS trg_rami_participant_end_check ON public.rami_participants; CREATE TRIGGER trg_rami_participant_end_check AFTER UPDATE ON public.rami_participants FOR EACH ROW EXECUTE FUNCTION _trg_rami_participant_end_check();
DROP TRIGGER IF EXISTS trg_tournaments_touch ON public.tournaments; CREATE TRIGGER trg_tournaments_touch BEFORE UPDATE ON public.tournaments FOR EACH ROW EXECUTE FUNCTION _t_touch();
DROP TRIGGER IF EXISTS trg_no_bot_tx ON public.transactions; CREATE TRIGGER trg_no_bot_tx BEFORE INSERT ON public.transactions FOR EACH ROW EXECUTE FUNCTION _trg_no_bot_tx();
DROP TRIGGER IF EXISTS trg_referral_on_stake ON public.transactions; CREATE TRIGGER trg_referral_on_stake AFTER INSERT ON public.transactions FOR EACH ROW EXECUTE FUNCTION _referral_on_stake();
DROP TRIGGER IF EXISTS trg_sync_profile_is_admin_del ON public.user_roles; CREATE TRIGGER trg_sync_profile_is_admin_del AFTER DELETE ON public.user_roles FOR EACH ROW EXECUTE FUNCTION sync_profile_is_admin();
DROP TRIGGER IF EXISTS trg_sync_profile_is_admin_ins ON public.user_roles; CREATE TRIGGER trg_sync_profile_is_admin_ins AFTER INSERT ON public.user_roles FOR EACH ROW EXECUTE FUNCTION sync_profile_is_admin();
DROP TRIGGER IF EXISTS trg_sync_profile_is_admin_upd ON public.user_roles; CREATE TRIGGER trg_sync_profile_is_admin_upd AFTER UPDATE ON public.user_roles FOR EACH ROW EXECUTE FUNCTION sync_profile_is_admin();

-- ═══════════ 0010_grants.sql ═══════════
-- 0010_grants.sql
-- Privilèges Data API (anon / authenticated / service_role)

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;





GRANT EXECUTE ON FUNCTION public._admin_has_active_session(_exclude_user uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._admin_has_active_session(_exclude_user uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._admin_has_active_session(_exclude_user uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._admin_log(_target uuid, _action text, _old jsonb, _new jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public._admin_log(_target uuid, _action text, _old jsonb, _new jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._admin_notify_others(_action text, _payload jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public._admin_notify_others(_action text, _payload jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public._admin_notify_others(_action text, _payload jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._admin_security_housekeeping() TO anon;
GRANT EXECUTE ON FUNCTION public._admin_security_housekeeping() TO authenticated;
GRANT EXECUTE ON FUNCTION public._admin_security_housekeeping() TO service_role;
GRANT EXECUTE ON FUNCTION public._afk_forfeit_player(_slug text, _game_id uuid, _uid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._afk_forfeit_player(_slug text, _game_id uuid, _uid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._afk_forfeit_player(_slug text, _game_id uuid, _uid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._app_settings_validate_trigger() TO anon;
GRANT EXECUTE ON FUNCTION public._app_settings_validate_trigger() TO authenticated;
GRANT EXECUTE ON FUNCTION public._app_settings_validate_trigger() TO service_role;
GRANT EXECUTE ON FUNCTION public._apply_game_commission() TO anon;
GRANT EXECUTE ON FUNCTION public._apply_game_commission() TO authenticated;
GRANT EXECUTE ON FUNCTION public._apply_game_commission() TO service_role;
GRANT EXECUTE ON FUNCTION public._assert_solo_bot_enabled() TO service_role;
GRANT EXECUTE ON FUNCTION public._auto_advance_overdue_turns() TO authenticated;
GRANT EXECUTE ON FUNCTION public._auto_advance_overdue_turns() TO service_role;
GRANT EXECUTE ON FUNCTION public._auto_cancel_open_games() TO authenticated;
GRANT EXECUTE ON FUNCTION public._auto_cancel_open_games() TO service_role;
GRANT EXECUTE ON FUNCTION public._auto_resume_paused_games() TO authenticated;
GRANT EXECUTE ON FUNCTION public._auto_resume_paused_games() TO service_role;
GRANT EXECUTE ON FUNCTION public._chat_snapshot_sender() TO anon;
GRANT EXECUTE ON FUNCTION public._chat_snapshot_sender() TO authenticated;
GRANT EXECUTE ON FUNCTION public._chat_snapshot_sender() TO service_role;
GRANT EXECUTE ON FUNCTION public._chess_ephemeral_bot(_pseudo text) TO anon;
GRANT EXECUTE ON FUNCTION public._chess_ephemeral_bot(_pseudo text) TO authenticated;
GRANT EXECUTE ON FUNCTION public._chess_ephemeral_bot(_pseudo text) TO service_role;
GRANT EXECUTE ON FUNCTION public._chess_gen_code() TO anon;
GRANT EXECUTE ON FUNCTION public._chess_gen_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public._chess_gen_code() TO service_role;
GRANT EXECUTE ON FUNCTION public._chess_payout(_game_id uuid, _winner uuid, _draw boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public._chess_payout(_game_id uuid, _winner uuid, _draw boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public._chess_settle(_id uuid, _winner uuid, _draw boolean, _reason text) TO anon;
GRANT EXECUTE ON FUNCTION public._chess_settle(_id uuid, _winner uuid, _draw boolean, _reason text) TO authenticated;
GRANT EXECUTE ON FUNCTION public._chess_settle(_id uuid, _winner uuid, _draw boolean, _reason text) TO service_role;
GRANT EXECUTE ON FUNCTION public._chess_sync_fen_turn(_fen text, _turn text) TO anon;
GRANT EXECUTE ON FUNCTION public._chess_sync_fen_turn(_fen text, _turn text) TO authenticated;
GRANT EXECUTE ON FUNCTION public._chess_sync_fen_turn(_fen text, _turn text) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_active_humans(_gid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._domino_active_humans(_gid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_active_humans(_gid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_apply_turn_timer() TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_arm_bot_think(_game_id uuid, _slot integer, _state jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_auto_draw(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._domino_auto_draw(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_auto_draw(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_autoplay_bots(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_bot_pick_move(_state jsonb, _slot integer, _intel integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_bot_step(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_bot_step(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_deal(_n_players integer) TO anon;
GRANT EXECUTE ON FUNCTION public._domino_deal(_n_players integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_deal(_n_players integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_end_round(_game_id uuid, _winner_slot integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_end_round(_game_id uuid, _winner_slot integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_finalize(_game_id uuid, _winner_slot integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_finalize(_game_id uuid, _winner_slot integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_hand_pips(_hand jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public._domino_hand_pips(_hand jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_hand_pips(_hand jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_init_state() TO anon;
GRANT EXECUTE ON FUNCTION public._domino_init_state() TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_init_state() TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_lock_game(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_lowest_pip_slot(_game_id uuid, _state jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_lowest_pip_slot(_game_id uuid, _state jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_next_playable_slot(_game_id uuid, _from_slot integer, _state jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_next_playable_slot(_game_id uuid, _from_slot integer, _state jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_next_round(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_next_round(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_normalize_board(_board jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_place_first(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_place_first(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_play_as(_game_id uuid, _slot integer, _move jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_purge(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._domino_purge(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_purge(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_required_starter_slot(_game_id uuid, _state jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_required_starter_slot(_game_id uuid, _state jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_slot_has_playable(_state jsonb, _slot integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_start(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_start(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_turn_state(_state jsonb, _turn_seconds integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._domino_visible(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._domino_visible(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._end_bot_only_games() TO anon;
GRANT EXECUTE ON FUNCTION public._end_bot_only_games() TO authenticated;
GRANT EXECUTE ON FUNCTION public._end_bot_only_games() TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_apply_move(_game_id uuid, _slot integer, _move jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public._fanorona_apply_move(_game_id uuid, _slot integer, _move jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_apply_move(_game_id uuid, _slot integer, _move jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_axis(_dr integer, _dc integer) TO anon;
GRANT EXECUTE ON FUNCTION public._fanorona_axis(_dr integer, _dc integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_axis(_dr integer, _dc integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_bot_pick_move(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._fanorona_bot_pick_move(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_bot_pick_move(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_capture_lists(_board jsonb, _my integer, _from integer, _to integer) TO anon;
GRANT EXECUTE ON FUNCTION public._fanorona_capture_lists(_board jsonb, _my integer, _from integer, _to integer, _cols integer, _rows integer) TO anon;
GRANT EXECUTE ON FUNCTION public._fanorona_capture_lists(_board jsonb, _my integer, _from integer, _to integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_capture_lists(_board jsonb, _my integer, _from integer, _to integer, _cols integer, _rows integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_capture_lists(_board jsonb, _my integer, _from integer, _to integer, _cols integer, _rows integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_capture_lists(_board jsonb, _my integer, _from integer, _to integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_draw_refund(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._fanorona_draw_refund(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_draw_refund(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_finalize(_game_id uuid, _winner_slot integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_finalize(_game_id uuid, _winner_slot integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_init_board(_cols integer, _rows integer) TO anon;
GRANT EXECUTE ON FUNCTION public._fanorona_init_board() TO anon;
GRANT EXECUTE ON FUNCTION public._fanorona_init_board() TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_init_board(_cols integer, _rows integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_init_board(_cols integer, _rows integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_init_board() TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_piece_can_capture(_board jsonb, _my integer, _idx integer, _visited jsonb, _last_axis text) TO anon;
GRANT EXECUTE ON FUNCTION public._fanorona_piece_can_capture(_board jsonb, _my integer, _idx integer, _visited jsonb, _last_axis text, _cols integer, _rows integer) TO anon;
GRANT EXECUTE ON FUNCTION public._fanorona_piece_can_capture(_board jsonb, _my integer, _idx integer, _visited jsonb, _last_axis text) TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_piece_can_capture(_board jsonb, _my integer, _idx integer, _visited jsonb, _last_axis text, _cols integer, _rows integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_piece_can_capture(_board jsonb, _my integer, _idx integer, _visited jsonb, _last_axis text, _cols integer, _rows integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_piece_can_capture(_board jsonb, _my integer, _idx integer, _visited jsonb, _last_axis text) TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_player_can_capture(_board jsonb, _my integer) TO anon;
GRANT EXECUTE ON FUNCTION public._fanorona_player_can_capture(_board jsonb, _my integer, _cols integer, _rows integer) TO anon;
GRANT EXECUTE ON FUNCTION public._fanorona_player_can_capture(_board jsonb, _my integer, _cols integer, _rows integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_player_can_capture(_board jsonb, _my integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_player_can_capture(_board jsonb, _my integer, _cols integer, _rows integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_player_can_capture(_board jsonb, _my integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_player_has_move(_board jsonb, _my integer, _cols integer, _rows integer) TO anon;
GRANT EXECUTE ON FUNCTION public._fanorona_player_has_move(_board jsonb, _my integer) TO anon;
GRANT EXECUTE ON FUNCTION public._fanorona_player_has_move(_board jsonb, _my integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_player_has_move(_board jsonb, _my integer, _cols integer, _rows integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_player_has_move(_board jsonb, _my integer, _cols integer, _rows integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_player_has_move(_board jsonb, _my integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._fanorona_visible(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._fanorona_visible(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._finance_tests_cleanup(_ids uuid[]) TO anon;
GRANT EXECUTE ON FUNCTION public._finance_tests_cleanup(_ids uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public._finance_tests_cleanup(_ids uuid[]) TO service_role;
GRANT EXECUTE ON FUNCTION public._game_cfg(_slug text) TO service_role;
GRANT EXECUTE ON FUNCTION public._game_resume_internal(_slug text, _game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._game_resume_internal(_slug text, _game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._game_visible(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._game_visible(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._gen_room_code() TO anon;
GRANT EXECUTE ON FUNCTION public._gen_room_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public._gen_room_code() TO service_role;
GRANT EXECUTE ON FUNCTION public._grant_admin_for_seed_emails() TO anon;
GRANT EXECUTE ON FUNCTION public._grant_admin_for_seed_emails() TO authenticated;
GRANT EXECUTE ON FUNCTION public._grant_admin_for_seed_emails() TO service_role;
GRANT EXECUTE ON FUNCTION public._guard_balance_non_negative() TO anon;
GRANT EXECUTE ON FUNCTION public._guard_balance_non_negative() TO authenticated;
GRANT EXECUTE ON FUNCTION public._guard_balance_non_negative() TO service_role;
GRANT EXECUTE ON FUNCTION public._is_game_participant(_game_id uuid, _user_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._is_game_participant(_game_id uuid, _user_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._is_valid_email(_raw text) TO anon;
GRANT EXECUTE ON FUNCTION public._is_valid_email(_raw text) TO authenticated;
GRANT EXECUTE ON FUNCTION public._is_valid_email(_raw text) TO service_role;
GRANT EXECUTE ON FUNCTION public._is_valid_http_url(_raw text) TO anon;
GRANT EXECUTE ON FUNCTION public._is_valid_http_url(_raw text) TO authenticated;
GRANT EXECUTE ON FUNCTION public._is_valid_http_url(_raw text) TO service_role;
GRANT EXECUTE ON FUNCTION public._is_valid_mg_phone(_raw text) TO anon;
GRANT EXECUTE ON FUNCTION public._is_valid_mg_phone(_raw text) TO authenticated;
GRANT EXECUTE ON FUNCTION public._is_valid_mg_phone(_raw text) TO service_role;
GRANT EXECUTE ON FUNCTION public._log_admin_action(_action text, _target_type text, _target_id uuid, _payload jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public._log_admin_action(_action text, _target_type text, _target_id uuid, _payload jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public._log_admin_action(_action text, _target_type text, _target_id uuid, _payload jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._log_house_on_finish() TO anon;
GRANT EXECUTE ON FUNCTION public._log_house_on_finish() TO authenticated;
GRANT EXECUTE ON FUNCTION public._log_house_on_finish() TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_active_humans(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._ludo_active_humans(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._ludo_active_humans(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_advance_turn(_game_id uuid, _new_slot integer, _last_event text) TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_auto_move(_game_id uuid, _slot integer) TO anon;
GRANT EXECUTE ON FUNCTION public._ludo_auto_move(_game_id uuid, _slot integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._ludo_auto_move(_game_id uuid, _slot integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_check_afk(_game_id uuid, _slot integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._ludo_check_afk(_game_id uuid, _slot integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_check_last_standing(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._ludo_check_last_standing(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._ludo_check_last_standing(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_ensure_state(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._ludo_ensure_state(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._ludo_ensure_state(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_init_state(_max_players integer) TO anon;
GRANT EXECUTE ON FUNCTION public._ludo_init_state(_max_players integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._ludo_init_state(_max_players integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_is_safe(_idx integer) TO anon;
GRANT EXECUTE ON FUNCTION public._ludo_is_safe(_idx integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._ludo_is_safe(_idx integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_next_slot(_game_id uuid, _from integer, _max integer) TO anon;
GRANT EXECUTE ON FUNCTION public._ludo_next_slot(_game_id uuid, _from integer, _max integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._ludo_next_slot(_game_id uuid, _from integer, _max integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_playable_pawns(_pawns jsonb, _slot integer, _dice integer) TO anon;
GRANT EXECUTE ON FUNCTION public._ludo_playable_pawns(_pawns jsonb, _slot integer, _dice integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._ludo_playable_pawns(_pawns jsonb, _slot integer, _dice integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_purge(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._ludo_purge(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._ludo_purge(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_push_move(_game_id uuid, _entry jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_set_ready_deadline() TO anon;
GRANT EXECUTE ON FUNCTION public._ludo_set_ready_deadline() TO authenticated;
GRANT EXECUTE ON FUNCTION public._ludo_set_ready_deadline() TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_start_for(_game_id uuid, _slot integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._ludo_start_for(_game_id uuid, _slot integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_start_idx(_slot integer) TO anon;
GRANT EXECUTE ON FUNCTION public._ludo_start_idx(_slot integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._ludo_start_idx(_slot integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._ludo_sync_turn_snapshot() TO anon;
GRANT EXECUTE ON FUNCTION public._ludo_sync_turn_snapshot() TO authenticated;
GRANT EXECUTE ON FUNCTION public._ludo_sync_turn_snapshot() TO service_role;
GRANT EXECUTE ON FUNCTION public._mark_first_game() TO authenticated;
GRANT EXECUTE ON FUNCTION public._mark_first_game() TO service_role;
GRANT EXECUTE ON FUNCTION public._maybe_end_bot_only_domino(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._maybe_end_bot_only_domino(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._maybe_end_bot_only_domino(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._maybe_end_bot_only_fanorona(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._maybe_end_bot_only_fanorona(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._maybe_end_bot_only_fanorona(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._maybe_end_bot_only_ludo(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._maybe_end_bot_only_ludo(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._maybe_end_bot_only_ludo(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._maybe_end_bot_only_rami(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._maybe_end_bot_only_rami(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._maybe_end_bot_only_rami(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._notify_deposit_created() TO anon;
GRANT EXECUTE ON FUNCTION public._notify_deposit_created() TO authenticated;
GRANT EXECUTE ON FUNCTION public._notify_deposit_created() TO service_role;
GRANT EXECUTE ON FUNCTION public._petanque_distance(ax double precision, ay double precision, bx double precision, by_ double precision) TO anon;
GRANT EXECUTE ON FUNCTION public._petanque_distance(ax double precision, ay double precision, bx double precision, by_ double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION public._petanque_distance(ax double precision, ay double precision, bx double precision, by_ double precision) TO service_role;
GRANT EXECUTE ON FUNCTION public._petanque_end_round(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._petanque_end_round(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._petanque_end_round(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._petanque_next_player(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._petanque_next_player(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._petanque_next_player(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._petanque_settle(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._petanque_settle(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._petanque_settle(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._petanque_simulate(p_throw_y double precision, p_angle double precision, p_power double precision, p_spin double precision, p_lob double precision) TO anon;
GRANT EXECUTE ON FUNCTION public._petanque_simulate(p_throw_y double precision, p_angle double precision, p_power double precision, p_spin double precision, p_lob double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION public._petanque_simulate(p_throw_y double precision, p_angle double precision, p_power double precision, p_spin double precision, p_lob double precision) TO service_role;
GRANT EXECUTE ON FUNCTION public._poker_apply_turn_timer() TO anon;
GRANT EXECUTE ON FUNCTION public._poker_apply_turn_timer() TO authenticated;
GRANT EXECUTE ON FUNCTION public._poker_apply_turn_timer() TO service_role;
GRANT EXECUTE ON FUNCTION public._poker_award(_gid uuid, _winner uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._poker_award(_gid uuid, _winner uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._poker_award(_gid uuid, _winner uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._poker_bot_act(_gid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._poker_bot_act(_gid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._poker_bot_act(_gid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._poker_hand_strength(hole integer[], community integer[]) TO anon;
GRANT EXECUTE ON FUNCTION public._poker_hand_strength(hole integer[], community integer[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public._poker_hand_strength(hole integer[], community integer[]) TO service_role;
GRANT EXECUTE ON FUNCTION public._prr_touch() TO anon;
GRANT EXECUTE ON FUNCTION public._prr_touch() TO authenticated;
GRANT EXECUTE ON FUNCTION public._prr_touch() TO service_role;
GRANT EXECUTE ON FUNCTION public._rami_active_humans(_gid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._rami_active_humans(_gid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._rami_active_humans(_gid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._rami_all_discards(_state jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public._rami_all_discards(_state jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public._rami_all_discards(_state jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._rami_autoplay_bots(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._rami_autoplay_bots(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._rami_autoplay_bots(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._rami_check_win(_state jsonb, _uid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._rami_check_win(_state jsonb, _key text) TO anon;
GRANT EXECUTE ON FUNCTION public._rami_check_win(_state jsonb, _key text) TO authenticated;
GRANT EXECUTE ON FUNCTION public._rami_check_win(_state jsonb, _uid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._rami_check_win(_state jsonb, _uid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._rami_check_win(_state jsonb, _key text) TO service_role;
GRANT EXECUTE ON FUNCTION public._rami_discards_map(_state jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public._rami_discards_map(_state jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public._rami_discards_map(_state jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._rami_gen_code() TO anon;
GRANT EXECUTE ON FUNCTION public._rami_gen_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public._rami_gen_code() TO service_role;
GRANT EXECUTE ON FUNCTION public._rami_is_joker(_c integer, _mode text, _rj integer) TO anon;
GRANT EXECUTE ON FUNCTION public._rami_is_joker(_c integer, _mode text, _rj integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._rami_is_joker(_c integer, _mode text, _rj integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._rami_last_discarder(_state jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public._rami_last_discarder(_state jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public._rami_last_discarder(_state jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._rami_meld_type(_cards integer[], _mode text, _rj integer) TO anon;
GRANT EXECUTE ON FUNCTION public._rami_meld_type(_cards integer[], _mode text, _rj integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._rami_meld_type(_cards integer[], _mode text, _rj integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._rami_normalize_state(_state jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public._rami_normalize_state(_state jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public._rami_normalize_state(_state jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._rami_remove_one(_arr integer[], _v integer) TO anon;
GRANT EXECUTE ON FUNCTION public._rami_remove_one(_arr integer[], _v integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._rami_remove_one(_arr integer[], _v integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._rami_reshuffle(_state jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public._rami_reshuffle(_state jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public._rami_reshuffle(_state jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public._rami_validate_meld(_cards integer[]) TO anon;
GRANT EXECUTE ON FUNCTION public._rami_validate_meld(_cards integer[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public._rami_validate_meld(_cards integer[]) TO service_role;
GRANT EXECUTE ON FUNCTION public._rami_visible(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._rami_visible(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._rami_visible(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._referral_on_deposit() TO authenticated;
GRANT EXECUTE ON FUNCTION public._referral_on_deposit() TO service_role;
GRANT EXECUTE ON FUNCTION public._referral_on_phone_verified() TO authenticated;
GRANT EXECUTE ON FUNCTION public._referral_on_phone_verified() TO service_role;
GRANT EXECUTE ON FUNCTION public._referral_on_signup() TO authenticated;
GRANT EXECUTE ON FUNCTION public._referral_on_signup() TO service_role;
GRANT EXECUTE ON FUNCTION public._referral_on_stake() TO anon;
GRANT EXECUTE ON FUNCTION public._referral_on_stake() TO authenticated;
GRANT EXECUTE ON FUNCTION public._referral_on_stake() TO service_role;
GRANT EXECUTE ON FUNCTION public._set_chess_global_deadline() TO authenticated;
GRANT EXECUTE ON FUNCTION public._set_chess_global_deadline() TO service_role;
GRANT EXECUTE ON FUNCTION public._set_fanorona_global_deadline() TO authenticated;
GRANT EXECUTE ON FUNCTION public._set_fanorona_global_deadline() TO service_role;
GRANT EXECUTE ON FUNCTION public._set_turn_deadline() TO anon;
GRANT EXECUTE ON FUNCTION public._set_turn_deadline() TO authenticated;
GRANT EXECUTE ON FUNCTION public._set_turn_deadline() TO service_role;
GRANT EXECUTE ON FUNCTION public._skip_noop_update() TO anon;
GRANT EXECUTE ON FUNCTION public._skip_noop_update() TO authenticated;
GRANT EXECUTE ON FUNCTION public._skip_noop_update() TO service_role;
GRANT EXECUTE ON FUNCTION public._sync_banned_flags() TO anon;
GRANT EXECUTE ON FUNCTION public._sync_banned_flags() TO authenticated;
GRANT EXECUTE ON FUNCTION public._sync_banned_flags() TO service_role;
GRANT EXECUTE ON FUNCTION public._t_build_round(_tid uuid, _round integer, _ids uuid[]) TO anon;
GRANT EXECUTE ON FUNCTION public._t_build_round(_tid uuid, _round integer, _ids uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public._t_build_round(_tid uuid, _round integer, _ids uuid[]) TO service_role;
GRANT EXECUTE ON FUNCTION public._t_draw_pools(_tid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._t_draw_pools(_tid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._t_draw_pools(_tid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._t_finish(_tid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._t_finish(_tid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._t_finish(_tid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._t_launch_match(_match_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._t_launch_match(_match_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._t_launch_match(_match_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._t_match_finish(_match_id uuid, _winner uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._t_match_finish(_match_id uuid, _winner uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._t_match_finish(_match_id uuid, _winner uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._t_notify(_entrant uuid, _title text, _body text, _link text) TO anon;
GRANT EXECUTE ON FUNCTION public._t_notify(_entrant uuid, _title text, _body text, _link text) TO authenticated;
GRANT EXECUTE ON FUNCTION public._t_notify(_entrant uuid, _title text, _body text, _link text) TO service_role;
GRANT EXECUTE ON FUNCTION public._t_pool_rank(_pool_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._t_pool_rank(_pool_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._t_pool_rank(_pool_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._t_pool_recompute(_pool_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._t_sim_resolve(_tid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._t_sim_resolve(_tid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._t_sim_resolve(_tid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._t_touch() TO anon;
GRANT EXECUTE ON FUNCTION public._t_touch() TO authenticated;
GRANT EXECUTE ON FUNCTION public._t_touch() TO service_role;
GRANT EXECUTE ON FUNCTION public._tmatch_set_join_deadline() TO anon;
GRANT EXECUTE ON FUNCTION public._tmatch_set_join_deadline() TO authenticated;
GRANT EXECUTE ON FUNCTION public._tmatch_set_join_deadline() TO service_role;
GRANT EXECUTE ON FUNCTION public._touch_shuffle_draft() TO anon;
GRANT EXECUTE ON FUNCTION public._touch_shuffle_draft() TO authenticated;
GRANT EXECUTE ON FUNCTION public._touch_shuffle_draft() TO service_role;
GRANT EXECUTE ON FUNCTION public._tourn_assign_ludo_waves(_tid uuid, _round integer) TO anon;
GRANT EXECUTE ON FUNCTION public._tourn_assign_ludo_waves(_tid uuid, _round integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._tourn_assign_ludo_waves(_tid uuid, _round integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._tourn_launch_after_finish() TO anon;
GRANT EXECUTE ON FUNCTION public._tourn_launch_after_finish() TO authenticated;
GRANT EXECUTE ON FUNCTION public._tourn_launch_after_finish() TO service_role;
GRANT EXECUTE ON FUNCTION public._tourn_launch_ludo_match(_match_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._tourn_launch_ludo_match(_match_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._tourn_launch_ludo_match(_match_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._tourn_ludo_active_count() TO anon;
GRANT EXECUTE ON FUNCTION public._tourn_ludo_active_count() TO authenticated;
GRANT EXECUTE ON FUNCTION public._tourn_ludo_active_count() TO service_role;
GRANT EXECUTE ON FUNCTION public._tourn_ludo_limit() TO anon;
GRANT EXECUTE ON FUNCTION public._tourn_ludo_limit() TO authenticated;
GRANT EXECUTE ON FUNCTION public._tourn_ludo_limit() TO service_role;
GRANT EXECUTE ON FUNCTION public._tourn_wave_for(_idx integer, _total integer, _limit integer) TO anon;
GRANT EXECUTE ON FUNCTION public._tourn_wave_for(_idx integer, _total integer, _limit integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._tourn_wave_for(_idx integer, _total integer, _limit integer) TO service_role;
GRANT EXECUTE ON FUNCTION public._tpool_notify(_uids uuid[], _title text, _body text, _tid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._tpool_touch() TO anon;
GRANT EXECUTE ON FUNCTION public._tpool_touch() TO authenticated;
GRANT EXECUTE ON FUNCTION public._tpool_touch() TO service_role;
GRANT EXECUTE ON FUNCTION public._trg_afk_warning_non_ludo() TO anon;
GRANT EXECUTE ON FUNCTION public._trg_afk_warning_non_ludo() TO authenticated;
GRANT EXECUTE ON FUNCTION public._trg_afk_warning_non_ludo() TO service_role;
GRANT EXECUTE ON FUNCTION public._trg_balance_audit() TO anon;
GRANT EXECUTE ON FUNCTION public._trg_balance_audit() TO authenticated;
GRANT EXECUTE ON FUNCTION public._trg_balance_audit() TO service_role;
GRANT EXECUTE ON FUNCTION public._trg_check_achievements_on_win() TO authenticated;
GRANT EXECUTE ON FUNCTION public._trg_check_achievements_on_win() TO service_role;
GRANT EXECUTE ON FUNCTION public._trg_domino_participant_end_check() TO anon;
GRANT EXECUTE ON FUNCTION public._trg_domino_participant_end_check() TO authenticated;
GRANT EXECUTE ON FUNCTION public._trg_domino_participant_end_check() TO service_role;
GRANT EXECUTE ON FUNCTION public._trg_fanorona_participant_end_check() TO anon;
GRANT EXECUTE ON FUNCTION public._trg_fanorona_participant_end_check() TO authenticated;
GRANT EXECUTE ON FUNCTION public._trg_fanorona_participant_end_check() TO service_role;
GRANT EXECUTE ON FUNCTION public._trg_ludo_participant_end_check() TO anon;
GRANT EXECUTE ON FUNCTION public._trg_ludo_participant_end_check() TO authenticated;
GRANT EXECUTE ON FUNCTION public._trg_ludo_participant_end_check() TO service_role;
GRANT EXECUTE ON FUNCTION public._trg_no_bot_money() TO anon;
GRANT EXECUTE ON FUNCTION public._trg_no_bot_money() TO authenticated;
GRANT EXECUTE ON FUNCTION public._trg_no_bot_money() TO service_role;
GRANT EXECUTE ON FUNCTION public._trg_no_bot_tx() TO anon;
GRANT EXECUTE ON FUNCTION public._trg_no_bot_tx() TO authenticated;
GRANT EXECUTE ON FUNCTION public._trg_no_bot_tx() TO service_role;
GRANT EXECUTE ON FUNCTION public._trg_pool_match_finished() TO anon;
GRANT EXECUTE ON FUNCTION public._trg_pool_match_finished() TO authenticated;
GRANT EXECUTE ON FUNCTION public._trg_pool_match_finished() TO service_role;
GRANT EXECUTE ON FUNCTION public._trg_rami_participant_end_check() TO anon;
GRANT EXECUTE ON FUNCTION public._trg_rami_participant_end_check() TO authenticated;
GRANT EXECUTE ON FUNCTION public._trg_rami_participant_end_check() TO service_role;
GRANT EXECUTE ON FUNCTION public._trg_third_place_auto_payout() TO anon;
GRANT EXECUTE ON FUNCTION public._trg_third_place_auto_payout() TO authenticated;
GRANT EXECUTE ON FUNCTION public._trg_third_place_auto_payout() TO service_role;
GRANT EXECUTE ON FUNCTION public._trg_third_place_notify() TO anon;
GRANT EXECUTE ON FUNCTION public._trg_third_place_notify() TO authenticated;
GRANT EXECUTE ON FUNCTION public._trg_third_place_notify() TO service_role;
GRANT EXECUTE ON FUNCTION public._trg_third_place_set_deadline() TO anon;
GRANT EXECUTE ON FUNCTION public._trg_third_place_set_deadline() TO authenticated;
GRANT EXECUTE ON FUNCTION public._trg_third_place_set_deadline() TO service_role;
GRANT EXECUTE ON FUNCTION public._try_unlock_referral(_uid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._try_unlock_referral(_uid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public._update_player_stats_on_win() TO authenticated;
GRANT EXECUTE ON FUNCTION public._update_player_stats_on_win() TO service_role;
GRANT EXECUTE ON FUNCTION public._validate_app_settings(_row app_settings) TO anon;
GRANT EXECUTE ON FUNCTION public._validate_app_settings(_row app_settings) TO authenticated;
GRANT EXECUTE ON FUNCTION public._validate_app_settings(_row app_settings) TO service_role;
GRANT EXECUTE ON FUNCTION public.accept_terms() TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_terms() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_activate_alias(p_alias_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_activate_alias(p_alias_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_activate_alias(p_alias_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_activate_persona(p_pseudo text, p_avatar_url text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_activate_persona(p_pseudo text, p_avatar_url text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_add_bot(_game_id uuid, _bot_name text, _intelligence integer, _win_bias integer) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_add_bot(_game_id uuid, _bot_name text, _intelligence integer, _win_bias integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_add_bot(_game_id uuid, _bot_name text, _intelligence integer, _win_bias integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_adjust_balance(_user_id uuid, _amount numeric, _note text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_adjust_balance(_user_id uuid, _amount numeric, _note text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_align_balances() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_align_balances() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_align_balances() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_announcement_create(_title text, _body text, _image_url text, _link text, _link_label text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_announcement_create(_title text, _body text, _image_url text, _link text, _link_label text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_announcement_create(_title text, _body text, _image_url text, _link text, _link_label text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_announcement_toggle(_id uuid, _active boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_announcement_toggle(_id uuid, _active boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_announcement_toggle(_id uuid, _active boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_audit_unlogged_changes(_hours integer) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_audit_unlogged_changes(_hours integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_audit_unlogged_changes(_hours integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_auto_process_expired_matches(_tid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_auto_process_expired_matches(_tid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_auto_process_expired_matches(_tid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_auto_start_ready_matches(_tid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_auto_start_ready_matches(_tid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_auto_start_ready_matches(_tid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_broadcast_delete(_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_broadcast_delete(_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_broadcast_send(_message text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_broadcast_send(_message text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_chat_mute(_user_id uuid, _minutes integer, _ban boolean, _reason text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_chat_mute(_user_id uuid, _minutes integer, _ban boolean, _reason text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_chat_unmute(_user_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_chat_unmute(_user_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_check_lockout(_user_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_check_lockout(_user_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_check_lockout(_user_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_close_expired_registrations() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_close_expired_registrations() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_close_expired_registrations() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_create_community(_name text, _image_url text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_community(_name text, _image_url text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_create_session(_mfa_verified boolean, _approval_id uuid, _ip inet, _user_agent text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_create_session(_mfa_verified boolean, _approval_id uuid, _ip inet, _user_agent text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_session(_mfa_verified boolean, _approval_id uuid, _ip inet, _user_agent text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_kpis() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_kpis() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_totals() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_totals() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_deactivate_persona() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_deactivate_persona() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_delete_alias(p_alias_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_alias(p_alias_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_alias(p_alias_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_delete_community(_room_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_community(_room_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_delete_game(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_game(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_dm_send(_user_id uuid, _message text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_dm_send(_user_id uuid, _message text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_finance_kpi() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_finance_kpi() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_finance_kpi() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_force_finish_game(_game_id uuid, _winner_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_force_finish_game(_game_id uuid, _winner_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_force_match_result(_mid uuid, _winner_id uuid, _reason text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_force_match_result(_mid uuid, _winner_id uuid, _reason text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_force_match_result(_mid uuid, _winner_id uuid, _reason text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_forfeit_match_player(_mid uuid, _loser_id uuid, _reason text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_forfeit_match_player(_mid uuid, _loser_id uuid, _reason text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_forfeit_match_player(_mid uuid, _loser_id uuid, _reason text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_games_history(_limit integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_games_history(_limit integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_get_forfeit_cron_info() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_get_forfeit_cron_info() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_forfeit_cron_info() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_get_fraud_flags(_status text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_fraud_flags(_status text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_get_intervention_dashboard() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_get_intervention_dashboard() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_intervention_dashboard() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_get_persona() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_persona() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_house_income(_since timestamp with time zone) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_house_income(_since timestamp with time zone) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_house_income(_since timestamp with time zone) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_join_game(_game_id uuid, _display_name text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_join_game(_game_id uuid, _display_name text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_leaderboard_list(_period text, _limit integer, _slug text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_leaderboard_list(_period text, _limit integer, _slug text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_leaderboard_list(_period text, _limit integer, _slug text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_aliases() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_list_aliases() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_aliases() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_all_active_sessions() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_list_all_active_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_all_active_sessions() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_bug_reports(_status text, _limit integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_bug_reports(_status text, _limit integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_games() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_games() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_my_sessions() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_list_my_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_my_sessions() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_phone_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_phone_requests() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_users() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_users() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_users_sorted(_sort text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_users_sorted(_sort text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_manual_payout(_uid uuid, _amount numeric, _reason text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_manual_payout(_uid uuid, _amount numeric, _reason text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_manual_payout(_uid uuid, _amount numeric, _reason text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_offer_delete(_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_offer_delete(_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_offer_delete(_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_offer_upsert(_id uuid, _title text, _description text, _image_url text, _link text, _expires_at timestamp with time zone, _active boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_offer_upsert(_id uuid, _title text, _description text, _image_url text, _link text, _expires_at timestamp with time zone, _active boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_offer_upsert(_id uuid, _title text, _description text, _image_url text, _link text, _expires_at timestamp with time zone, _active boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_override_login(_reason text, _ip inet, _user_agent text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_override_login(_reason text, _ip inet, _user_agent text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_override_login(_reason text, _ip inet, _user_agent text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_override_match_winner(_mid uuid, _winner_id uuid, _reason text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_override_match_winner(_mid uuid, _winner_id uuid, _reason text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_override_match_winner(_mid uuid, _winner_id uuid, _reason text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_permanently_delete_user(_user_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_permanently_delete_user(_user_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_process_deposit(_id uuid, _approve boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_process_deposit(_id uuid, _approve boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_process_withdrawal(_id uuid, _approve boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_process_withdrawal(_id uuid, _approve boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_reconcile_balances() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_reconcile_balances() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reconcile_balances() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_record_login_attempt(_user_id uuid, _success boolean, _reason text, _ip inet, _ua text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_record_login_attempt(_user_id uuid, _success boolean, _reason text, _ip inet, _ua text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_record_login_attempt(_user_id uuid, _success boolean, _reason text, _ip inet, _ua text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_refund_game(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_refund_game(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_reply_support(_id uuid, _reply text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reply_support(_id uuid, _reply text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_request_login_approval(_ip inet, _user_agent text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_request_login_approval(_ip inet, _user_agent text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_request_login_approval(_ip inet, _user_agent text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_reset_all_terms() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reset_all_terms() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_resolve_claim(_cid uuid, _status text, _comment text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_claim(_cid uuid, _status text, _comment text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_claim(_cid uuid, _status text, _comment text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_resolve_fraud_flag(_flag_id uuid, _resolution text, _pay_anyway boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_fraud_flag(_flag_id uuid, _resolution text, _pay_anyway boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_respond_login_approval(_request_id uuid, _decision text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_respond_login_approval(_request_id uuid, _decision text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_respond_login_approval(_request_id uuid, _decision text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_revoke_all_other_sessions() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_revoke_all_other_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_revoke_all_other_sessions() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_revoke_any_session(_session_id uuid, _reason text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_revoke_any_session(_session_id uuid, _reason text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_revoke_any_session(_session_id uuid, _reason text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_revoke_session(_session_id uuid, _reason text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_revoke_session(_session_id uuid, _reason text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_revoke_session(_session_id uuid, _reason text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_save_alias(p_pseudo text, p_avatar_url text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_save_alias(p_pseudo text, p_avatar_url text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_alias(p_pseudo text, p_avatar_url text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_search_users(_q text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_search_users(_q text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_send_email_otp() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_send_email_otp() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_send_email_otp() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_daily_bonus(_enabled boolean, _amount_ar integer, _streak_bonus boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_daily_bonus(_enabled boolean, _amount_ar integer, _streak_bonus boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_forfeit_cron_interval(_seconds integer) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_set_forfeit_cron_interval(_seconds integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_forfeit_cron_interval(_seconds integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_leaderboard_hidden(_user_id uuid, _hidden boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_set_leaderboard_hidden(_user_id uuid, _hidden boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_leaderboard_hidden(_user_id uuid, _hidden boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_leaderboard_rank(_user_id uuid, _rank integer) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_set_leaderboard_rank(_user_id uuid, _rank integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_leaderboard_rank(_user_id uuid, _rank integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_pause(_paused boolean, _message text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_pause(_paused boolean, _message text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_reward_distribution(_tid uuid, _first_pct numeric, _second_pct numeric, _third_pct numeric, _platform_pct numeric) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_set_reward_distribution(_tid uuid, _first_pct numeric, _second_pct numeric, _third_pct numeric, _platform_pct numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_reward_distribution(_tid uuid, _first_pct numeric, _second_pct numeric, _third_pct numeric, _platform_pct numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_user_banned(_user_id uuid, _banned boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_banned(_user_id uuid, _banned boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_user_status(_user_id uuid, _status text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_status(_user_id uuid, _status text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_stats_daily(_days integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_stats_daily(_days integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_suspend_player(_uid uuid, _hours integer, _reason text, _add_warning boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_suspend_player(_uid uuid, _hours integer, _reason text, _add_warning boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_suspend_player(_uid uuid, _hours integer, _reason text, _add_warning boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_top_referrers() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_top_referrers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_top_referrers() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_tournament_add_bots(_tid uuid, _count integer) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_tournament_add_bots(_tid uuid, _count integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_tournament_add_bots(_tid uuid, _count integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_tournament_cancel(_tid uuid, _reason text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_tournament_cancel(_tid uuid, _reason text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_tournament_cancel(_tid uuid, _reason text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_tournament_create(_name text, _game_slug text, _format text, _players_per_match integer, _max_players integer, _entry_fee_ar numeric, _admin_prize_pool_ar numeric, _winners_count integer, _p1 numeric, _p2 numeric, _p3 numeric, _pool_size integer, _qualifiers_per_pool integer, _max_concurrent integer, _lobby_minutes integer, _description text, _registration_closes_at timestamp with time zone, _starts_at timestamp with time zone) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_tournament_create(_name text, _game_slug text, _format text, _players_per_match integer, _max_players integer, _entry_fee_ar numeric, _admin_prize_pool_ar numeric, _winners_count integer, _p1 numeric, _p2 numeric, _p3 numeric, _pool_size integer, _qualifiers_per_pool integer, _max_concurrent integer, _lobby_minutes integer, _description text, _registration_closes_at timestamp with time zone, _starts_at timestamp with time zone) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_tournament_create(_name text, _game_slug text, _format text, _players_per_match integer, _max_players integer, _entry_fee_ar numeric, _admin_prize_pool_ar numeric, _winners_count integer, _p1 numeric, _p2 numeric, _p3 numeric, _pool_size integer, _qualifiers_per_pool integer, _max_concurrent integer, _lobby_minutes integer, _description text, _registration_closes_at timestamp with time zone, _starts_at timestamp with time zone) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_tournament_delete(_tid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_tournament_delete(_tid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_tournament_delete(_tid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_tournament_force_winner(_match_id uuid, _entrant_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_tournament_force_winner(_match_id uuid, _entrant_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_tournament_force_winner(_match_id uuid, _entrant_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_tournament_next_stage(_tid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_tournament_next_stage(_tid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_tournament_next_stage(_tid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_tournament_set_auto(_tid uuid, _auto boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_tournament_set_auto(_tid uuid, _auto boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_tournament_set_auto(_tid uuid, _auto boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_tournament_set_status(_tid uuid, _status text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_tournament_set_status(_tid uuid, _status text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_tournament_set_status(_tid uuid, _status text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_tournament_simulate(_tid uuid, _max_steps integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_tournament_simulate(_tid uuid, _max_steps integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_tournament_simulate_new(_game_slug text, _format text, _players integer, _players_per_match integer, _pool_size integer, _qualifiers_per_pool integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_tournament_simulate_new(_game_slug text, _format text, _players integer, _players_per_match integer, _pool_size integer, _qualifiers_per_pool integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_tournament_start(_tid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_tournament_start(_tid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_tournament_start(_tid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_bug_report(_id uuid, _status text, _admin_note text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_bug_report(_id uuid, _status text, _admin_note text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_cms_content(_key text, _content jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_update_cms_content(_key text, _content jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_cms_content(_key text, _content jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_community(_room_id uuid, _name text, _image_url text, _enabled boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_community(_room_id uuid, _name text, _image_url text, _enabled boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_referral_settings(_enabled boolean, _stake_commission_pct numeric, _stake_commission_max_matches integer, _require_phone boolean, _max_daily integer, _auto_flag_velocity integer, _campaign_label text, _campaign_expires timestamp with time zone, _campaign_bonus_pct numeric) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_update_referral_settings(_enabled boolean, _stake_commission_pct numeric, _stake_commission_max_matches integer, _require_phone boolean, _max_daily integer, _auto_flag_velocity integer, _campaign_label text, _campaign_expires timestamp with time zone, _campaign_bonus_pct numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_referral_settings(_enabled boolean, _stake_commission_pct numeric, _stake_commission_max_matches integer, _require_phone boolean, _max_daily integer, _auto_flag_velocity integer, _campaign_label text, _campaign_expires timestamp with time zone, _campaign_bonus_pct numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_settings(_admin_phone text, _admin_label text, _signup_bonus numeric, _referral_pct numeric, _game_commission_pct numeric, _min_deposit numeric, _min_withdraw numeric, _mvola_phone text, _mvola_name text, _orange_phone text, _orange_name text, _airtel_phone text, _airtel_name text, _withdrawal_fee_pct numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_user_history(_user_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_user_history(_user_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_validate_round(_tid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_validate_round(_tid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_validate_round(_tid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_validate_session(_fingerprint text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_validate_session(_fingerprint text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_validate_session(_fingerprint text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_verify_email_otp(_code text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_verify_email_otp(_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_verify_email_otp(_code text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_verify_phone(_user_id uuid, _approve boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_verify_phone(_user_id uuid, _approve boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.can_access_realtime_topic(_topic text) TO anon;
GRANT EXECUTE ON FUNCTION public.can_access_realtime_topic(_topic text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_realtime_topic(_topic text) TO service_role;
GRANT EXECUTE ON FUNCTION public.chat_get_or_create_dm(_other uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chat_get_or_create_dm(_other uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.chat_get_or_create_game_room(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chat_get_or_create_game_room(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.chat_join_room(_room_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chat_join_room(_room_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.chat_leave_room(_room_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chat_leave_room(_room_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.chat_pin(_message_id uuid, _pin boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chat_pin(_message_id uuid, _pin boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.chat_presence_ping(_game uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chat_presence_ping(_game uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.chat_send(_room_id uuid, _body text, _reply_to uuid, _attachment_url text, _attachment_type text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chat_send(_room_id uuid, _body text, _reply_to uuid, _attachment_url text, _attachment_type text) TO service_role;
GRANT EXECUTE ON FUNCTION public.chat_typing(_room_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chat_typing(_room_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.check_and_award_achievements(_uid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_and_award_achievements(_uid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.check_pseudo_availability(_pseudo text) TO anon;
GRANT EXECUTE ON FUNCTION public.check_pseudo_availability(_pseudo text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_pseudo_availability(_pseudo text) TO service_role;
GRANT EXECUTE ON FUNCTION public.check_pseudo_available(p_pseudo text) TO anon;
GRANT EXECUTE ON FUNCTION public.check_pseudo_available(p_pseudo text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_pseudo_available(p_pseudo text) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_accept_draw(_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.chess_accept_draw(_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_accept_draw(_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_add_bot(_game_id uuid, _difficulty text) TO anon;
GRANT EXECUTE ON FUNCTION public.chess_add_bot(_game_id uuid, _difficulty text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_add_bot(_game_id uuid, _difficulty text) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_auto_end(_game_id uuid, _winner uuid, _draw boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_auto_end(_game_id uuid, _winner uuid, _draw boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_bot_play(_id uuid, _uci text, _san text, _fen_after text, _elapsed_ms integer) TO anon;
GRANT EXECUTE ON FUNCTION public.chess_bot_play(_id uuid, _uci text, _san text, _fen_after text, _elapsed_ms integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_bot_play(_id uuid, _uci text, _san text, _fen_after text, _elapsed_ms integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_check_global_timeout(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_check_global_timeout(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_claim_win(_game_id uuid, _winner uuid, _draw boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_claim_win(_game_id uuid, _winner uuid, _draw boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_create(_stake numeric, _private boolean, _commission numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_create(_stake numeric, _private boolean, _commission numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_create_friends(_color text, _time_min integer) TO anon;
GRANT EXECUTE ON FUNCTION public.chess_create_friends(_color text, _time_min integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_create_friends(_color text, _time_min integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_create_solo(_difficulty integer, _color text, _time_min integer) TO anon;
GRANT EXECUTE ON FUNCTION public.chess_create_solo(_difficulty integer, _color text, _time_min integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_create_solo(_difficulty integer, _color text, _time_min integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_create_stake(_stake numeric, _color text, _time_min integer) TO anon;
GRANT EXECUTE ON FUNCTION public.chess_create_stake(_stake numeric, _color text, _time_min integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_create_stake(_stake numeric, _color text, _time_min integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_decline_draw(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_decline_draw(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_draw_finalize(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_draw_finalize(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_draw_pick_color(_game_id uuid, _color text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_draw_pick_color(_game_id uuid, _color text) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_finish(_id uuid, _winner uuid, _draw boolean, _reason text) TO anon;
GRANT EXECUTE ON FUNCTION public.chess_finish(_id uuid, _winner uuid, _draw boolean, _reason text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_finish(_id uuid, _winner uuid, _draw boolean, _reason text) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_join(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.chess_join(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_join(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_join_friends(_code text) TO anon;
GRANT EXECUTE ON FUNCTION public.chess_join_friends(_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_join_friends(_code text) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_join_stake(_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.chess_join_stake(_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_join_stake(_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_offer_draw(_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.chess_offer_draw(_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_offer_draw(_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_play(_id uuid, _uci text, _san text, _fen_after text, _elapsed_ms integer) TO anon;
GRANT EXECUTE ON FUNCTION public.chess_play(_id uuid, _uci text, _san text, _fen_after text, _elapsed_ms integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_play(_id uuid, _uci text, _san text, _fen_after text, _elapsed_ms integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_request_or_accept_draw(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_request_or_accept_draw(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_resign(_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.chess_resign(_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_resign(_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_set_ready(_game_id uuid, _ready boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_set_ready(_game_id uuid, _ready boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_start_solo_bot(_difficulty text, _color text) TO anon;
GRANT EXECUTE ON FUNCTION public.chess_start_solo_bot(_difficulty text, _color text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_start_solo_bot(_difficulty text, _color text) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_tick(_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.chess_tick(_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_tick(_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.chess_tick_all() TO anon;
GRANT EXECUTE ON FUNCTION public.chess_tick_all() TO authenticated;
GRANT EXECUTE ON FUNCTION public.chess_tick_all() TO service_role;
GRANT EXECUTE ON FUNCTION public.claim_daily_bonus() TO anon;
GRANT EXECUTE ON FUNCTION public.claim_daily_bonus() TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_daily_bonus() TO service_role;
GRANT EXECUTE ON FUNCTION public.cleanup_stale_open_games() TO anon;
GRANT EXECUTE ON FUNCTION public.cleanup_stale_open_games() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_stale_open_games() TO service_role;
GRANT EXECUTE ON FUNCTION public.create_game(_max_players integer, _stake numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_game(_max_players integer, _stake numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_private_game(_max_players integer, _stake numeric, _mode text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_private_game(_max_players integer, _stake numeric, _mode text) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_public_game(_max_players integer, _stake numeric, _mode text) TO anon;
GRANT EXECUTE ON FUNCTION public.create_public_game(_max_players integer, _stake numeric, _mode text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_public_game(_max_players integer, _stake numeric, _mode text) TO service_role;
GRANT EXECUTE ON FUNCTION public.credit_user_balance(_user_id uuid, _amount numeric, _type text, _ref_id uuid, _note text, _meta jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.credit_user_balance(_user_id uuid, _amount numeric, _type text, _ref_id uuid, _note text, _meta jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.credit_user_balance(_user_id uuid, _amount numeric, _type text, _ref_id uuid, _note text, _meta jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.debit_user_balance(_user_id uuid, _amount numeric, _type text, _ref_id uuid, _note text, _meta jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.debit_user_balance(_user_id uuid, _amount numeric, _type text, _ref_id uuid, _note text, _meta jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.debit_user_balance(_user_id uuid, _amount numeric, _type text, _ref_id uuid, _note text, _meta jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO service_role;
GRANT EXECUTE ON FUNCTION public.domino_add_bot(_game_id uuid, _bot_name text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.domino_add_bot(_game_id uuid, _bot_name text) TO service_role;
GRANT EXECUTE ON FUNCTION public.domino_create(_stake numeric, _max integer, _private boolean, _mode text, _commission numeric, _target_score integer, _draw_mode text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.domino_create(_stake numeric, _max integer, _private boolean, _mode text, _commission numeric, _target_score integer, _draw_mode text, _first_tile_rule text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.domino_create(_stake numeric, _max integer, _private boolean, _mode text, _commission numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.domino_create(_stake numeric, _max integer, _private boolean, _mode text, _commission numeric, _target_score integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.domino_create(_stake numeric, _max integer, _private boolean, _mode text, _commission numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.domino_create(_stake numeric, _max integer, _private boolean, _mode text, _commission numeric, _target_score integer, _draw_mode text) TO service_role;
GRANT EXECUTE ON FUNCTION public.domino_create(_stake numeric, _max integer, _private boolean, _mode text, _commission numeric, _target_score integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.domino_create(_stake numeric, _max integer, _private boolean, _mode text, _commission numeric, _target_score integer, _draw_mode text, _first_tile_rule text) TO service_role;
GRANT EXECUTE ON FUNCTION public.domino_forfeit(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.domino_forfeit(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.domino_join(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.domino_join(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.domino_join_code(_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.domino_join_code(_code text) TO service_role;
GRANT EXECUTE ON FUNCTION public.domino_play(_game_id uuid, _move jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.domino_play(_game_id uuid, _move jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.domino_play_and_bot(_game_id uuid, _move jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.domino_play_and_bot(_game_id uuid, _move jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.domino_set_ready(_game_id uuid, _ready boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.domino_set_ready(_game_id uuid, _ready boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.domino_start_solo_bot(_max_players integer, _difficulty text, _target_score integer, _draw_mode text, _first_tile_rule text) TO anon;
GRANT EXECUTE ON FUNCTION public.domino_start_solo_bot(_max_players integer, _difficulty text, _target_score integer, _draw_mode text, _first_tile_rule text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.domino_start_solo_bot(_max_players integer, _difficulty text, _target_score integer, _draw_mode text, _first_tile_rule text) TO service_role;
GRANT EXECUTE ON FUNCTION public.domino_tick(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.domino_tick(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.domino_tick_all() TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_add_bot(_game_id uuid, _bot_name text) TO anon;
GRANT EXECUTE ON FUNCTION public.fanorona_add_bot(_game_id uuid, _bot_name text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_add_bot(_game_id uuid, _bot_name text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_bot_play(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.fanorona_bot_play(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_bot_play(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_check_global_timeout(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_check_global_timeout(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_create(_stake numeric, _private boolean, _commission numeric, _variant text, _mandatory_capture boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_create(_stake numeric, _private boolean, _commission numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_create(_stake numeric, _private boolean, _commission numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_create(_stake numeric, _private boolean, _commission numeric, _variant text, _mandatory_capture boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_draw_finalize(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_draw_finalize(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_draw_pick_color(_game_id uuid, _color text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_draw_pick_color(_game_id uuid, _color text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_draw_spin(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_draw_spin(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_forfeit(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_forfeit(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_join(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_join(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_join_code(_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_join_code(_code text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_play(_game_id uuid, _move jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_play(_game_id uuid, _move jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_play_as_bot(_game_id uuid, _move jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.fanorona_play_as_bot(_game_id uuid, _move jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_play_as_bot(_game_id uuid, _move jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_request_or_accept_draw(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_request_or_accept_draw(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_set_ready(_game_id uuid, _ready boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_set_ready(_game_id uuid, _ready boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_start_solo_bot(_variant text, _mandatory_capture boolean, _difficulty text) TO anon;
GRANT EXECUTE ON FUNCTION public.fanorona_start_solo_bot(_variant text, _mandatory_capture boolean, _difficulty text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_start_solo_bot(_variant text, _mandatory_capture boolean, _difficulty text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fanorona_tick(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fanorona_tick(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.find_or_create_game(_max_players integer, _stake numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.find_or_create_game(_max_players integer, _stake numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_game(_game_id uuid, _winner_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finish_game(_game_id uuid, _winner_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.friendships_touch_updated_at() TO anon;
GRANT EXECUTE ON FUNCTION public.friendships_touch_updated_at() TO authenticated;
GRANT EXECUTE ON FUNCTION public.friendships_touch_updated_at() TO service_role;
GRANT EXECUTE ON FUNCTION public.game_online_count(_slug text) TO anon;
GRANT EXECUTE ON FUNCTION public.game_online_count(_slug text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.game_online_count(_slug text) TO service_role;
GRANT EXECUTE ON FUNCTION public.game_player_status(_user_id uuid, _slug text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.game_player_status(_user_id uuid, _slug text) TO service_role;
GRANT EXECUTE ON FUNCTION public.game_request_afk_pause(_slug text, _game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.game_request_afk_pause(_slug text, _game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.game_request_afk_pause(_slug text, _game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.game_request_pause(_slug text, _game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.game_request_pause(_slug text, _game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.game_resume(_slug text, _game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.game_resume(_slug text, _game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.gen_referral_code() TO anon;
GRANT EXECUTE ON FUNCTION public.gen_referral_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public.gen_referral_code() TO service_role;
GRANT EXECUTE ON FUNCTION public.gen_unique_code() TO anon;
GRANT EXECUTE ON FUNCTION public.gen_unique_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public.gen_unique_code() TO service_role;
GRANT EXECUTE ON FUNCTION public.get_ai_assistant_settings() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_ai_assistant_settings() TO service_role;
GRANT EXECUTE ON FUNCTION public.get_daily_bonus_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_bonus_status() TO service_role;
GRANT EXECUTE ON FUNCTION public.get_email_by_phone(_phone text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_email_by_phone(_phone text) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_full_history(_uid uuid, _limit integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_full_history(_uid uuid, _limit integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_game_commission(_game text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_game_commission(_game text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_game_commission(_game text) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_legal_texts() TO anon;
GRANT EXECUTE ON FUNCTION public.get_legal_texts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_legal_texts() TO service_role;
GRANT EXECUTE ON FUNCTION public.get_my_referrals() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_referrals() TO service_role;
GRANT EXECUTE ON FUNCTION public.get_player_achievements(_uid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_player_achievements(_uid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_poker_hand_history(_user_id uuid, _limit integer) TO anon;
GRANT EXECUTE ON FUNCTION public.get_poker_hand_history(_user_id uuid, _limit integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_poker_hand_history(_user_id uuid, _limit integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_public_help_texts() TO anon;
GRANT EXECUTE ON FUNCTION public.get_public_help_texts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_help_texts() TO service_role;
GRANT EXECUTE ON FUNCTION public.get_public_profile(_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.get_public_profile(_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_profile(_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_public_profiles_min(_ids uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_profiles_min(_ids uuid[]) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_referral_dashboard() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_referral_dashboard() TO service_role;
GRANT EXECUTE ON FUNCTION public.get_referral_leaderboard(_limit integer) TO anon;
GRANT EXECUTE ON FUNCTION public.get_referral_leaderboard(_limit integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_referral_leaderboard(_limit integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.gi_touch_updated_at() TO anon;
GRANT EXECUTE ON FUNCTION public.gi_touch_updated_at() TO authenticated;
GRANT EXECUTE ON FUNCTION public.gi_touch_updated_at() TO service_role;
GRANT EXECUTE ON FUNCTION public.hall_of_fame() TO authenticated;
GRANT EXECUTE ON FUNCTION public.hall_of_fame() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.has_role(_user_id uuid, _role app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_role(_user_id uuid, _role app_role) TO service_role;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO service_role;
GRANT EXECUTE ON FUNCTION public.is_game_disabled(_slug text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_game_disabled(_slug text) TO service_role;
GRANT EXECUTE ON FUNCTION public.join_game(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_game(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.join_game_by_code(_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_game_by_code(_code text) TO service_role;
GRANT EXECUTE ON FUNCTION public.leaderboard_winners(_period text, _limit integer, _slug text) TO anon;
GRANT EXECUTE ON FUNCTION public.leaderboard_winners(_period text, _limit integer, _slug text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leaderboard_winners(_period text, _limit integer, _slug text) TO service_role;
GRANT EXECUTE ON FUNCTION public.list_live_games() TO anon;
GRANT EXECUTE ON FUNCTION public.list_live_games() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_live_games() TO service_role;
GRANT EXECUTE ON FUNCTION public.list_players_for_dm(_search text, _limit integer) TO anon;
GRANT EXECUTE ON FUNCTION public.list_players_for_dm() TO anon;
GRANT EXECUTE ON FUNCTION public.list_players_for_dm() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_players_for_dm(_search text, _limit integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_players_for_dm() TO service_role;
GRANT EXECUTE ON FUNCTION public.list_players_for_dm(_search text, _limit integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.list_public_open_games() TO anon;
GRANT EXECUTE ON FUNCTION public.list_public_open_games() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_public_open_games() TO service_role;
GRANT EXECUTE ON FUNCTION public.list_tournaments(_status text, _game_slug text, _limit integer) TO anon;
GRANT EXECUTE ON FUNCTION public.list_tournaments(_status text, _game_slug text, _limit integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_tournaments(_status text, _game_slug text, _limit integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_bot_step(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_bot_step(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_check_timeout(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_check_timeout(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_cleanup_empty_rooms() TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_cleanup_empty_rooms() TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_create_friends_game(_max_players integer, _stake numeric, _mode text, _is_public boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_create_friends_game(_max_players integer, _stake numeric, _mode text, _is_public boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_heartbeat(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_heartbeat(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_join(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.ludo_join(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_join(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_move(_game_id uuid, _pawn_idx integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_move(_game_id uuid, _pawn_idx integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_pass(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_pass(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_purge_unready_rooms() TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_purge_unready_rooms() TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_quit(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_quit(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_roll(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_roll(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_set_auto_move(_game_id uuid, _enabled boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.ludo_set_auto_move(_game_id uuid, _enabled boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_set_auto_move(_game_id uuid, _enabled boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_set_display_name(_game_id uuid, _name text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_set_display_name(_game_id uuid, _name text) TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_set_ready(_game_id uuid, _ready boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_set_ready(_game_id uuid, _ready boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_start_solo_bot(_max_players integer, _difficulty text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_start_solo_bot(_max_players integer, _difficulty text) TO service_role;
GRANT EXECUTE ON FUNCTION public.ludo_tick_all() TO authenticated;
GRANT EXECUTE ON FUNCTION public.ludo_tick_all() TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_messages_read() TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_messages_read() TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_notif_read(_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_notif_read(_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.my_games() TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_games() TO service_role;
GRANT EXECUTE ON FUNCTION public.my_ongoing_all() TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_ongoing_all() TO service_role;
GRANT EXECUTE ON FUNCTION public.participant_rename(_game_id uuid, _name text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.participant_rename(_game_id uuid, _name text) TO service_role;
GRANT EXECUTE ON FUNCTION public.petanque_add_bot(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.petanque_add_bot(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.petanque_add_bot(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.petanque_bot_step(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.petanque_bot_step(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.petanque_bot_step(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.petanque_create(p_stake numeric, p_public boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.petanque_create(p_stake numeric, p_public boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.petanque_create(p_stake numeric, p_public boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.petanque_join(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.petanque_join(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.petanque_join(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.petanque_join_code(_code text) TO anon;
GRANT EXECUTE ON FUNCTION public.petanque_join_code(_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.petanque_join_code(_code text) TO service_role;
GRANT EXECUTE ON FUNCTION public.petanque_leave(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.petanque_leave(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.petanque_leave(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.petanque_set_ready(_game_id uuid, _ready boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.petanque_set_ready(_game_id uuid, _ready boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.petanque_set_ready(_game_id uuid, _ready boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.petanque_throw(_game_id uuid, _angle double precision, _power double precision, _spin double precision, _lob double precision) TO anon;
GRANT EXECUTE ON FUNCTION public.petanque_throw(_game_id uuid, _angle double precision, _power double precision, _spin double precision, _lob double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION public.petanque_throw(_game_id uuid, _angle double precision, _power double precision, _spin double precision, _lob double precision) TO service_role;
GRANT EXECUTE ON FUNCTION public.player_add_bot(_game_id uuid, _bot_name text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.player_add_bot(_game_id uuid, _bot_name text) TO service_role;
GRANT EXECUTE ON FUNCTION public.player_submit_claim(_tournament_id uuid, _match_id uuid, _category text, _description text) TO anon;
GRANT EXECUTE ON FUNCTION public.player_submit_claim(_tournament_id uuid, _match_id uuid, _category text, _description text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.player_submit_claim(_tournament_id uuid, _match_id uuid, _category text, _description text) TO service_role;
GRANT EXECUTE ON FUNCTION public.poker_action(_game_id uuid, _action text, _amount numeric) TO anon;
GRANT EXECUTE ON FUNCTION public.poker_action(_game_id uuid, _action text, _amount numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poker_action(_game_id uuid, _action text, _amount numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.poker_add_bot(_game_id uuid, _bot_name text) TO anon;
GRANT EXECUTE ON FUNCTION public.poker_add_bot(_game_id uuid, _bot_name text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poker_add_bot(_game_id uuid, _bot_name text) TO service_role;
GRANT EXECUTE ON FUNCTION public.poker_autoplay_bots(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.poker_autoplay_bots(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poker_autoplay_bots(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.poker_join(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.poker_join(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poker_join(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.poker_my_hole_cards(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poker_my_hole_cards(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.poker_set_ready(_game_id uuid, _ready boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.poker_set_ready(_game_id uuid, _ready boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poker_set_ready(_game_id uuid, _ready boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.poker_start_next_hand(_game_id uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.poker_start_next_hand(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poker_start_next_hand(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.poker_start_solo_bot(_max_players integer, _difficulty text) TO anon;
GRANT EXECUTE ON FUNCTION public.poker_start_solo_bot(_max_players integer, _difficulty text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poker_start_solo_bot(_max_players integer, _difficulty text) TO service_role;
GRANT EXECUTE ON FUNCTION public.rami_add_bot(_game_id uuid, _bot_name text) TO anon;
GRANT EXECUTE ON FUNCTION public.rami_add_bot(_game_id uuid, _bot_name text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rami_add_bot(_game_id uuid, _bot_name text) TO service_role;
GRANT EXECUTE ON FUNCTION public.rami_create(_stake numeric, _max integer, _private boolean, _commission integer, _joker_mode text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rami_create(_stake numeric, _max integer, _private boolean, _commission integer, _joker_mode text) TO service_role;
GRANT EXECUTE ON FUNCTION public.rami_discard(_game_id uuid, _card integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rami_discard(_game_id uuid, _card integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.rami_draw(_game_id uuid, _from text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rami_draw(_game_id uuid, _from text) TO service_role;
GRANT EXECUTE ON FUNCTION public.rami_forfeit(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rami_forfeit(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.rami_join(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rami_join(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.rami_join_code(_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rami_join_code(_code text) TO service_role;
GRANT EXECUTE ON FUNCTION public.rami_layoff(_game_id uuid, _meld_index integer, _cards integer[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rami_layoff(_game_id uuid, _meld_index integer, _cards integer[]) TO service_role;
GRANT EXECUTE ON FUNCTION public.rami_meld(_game_id uuid, _cards integer[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rami_meld(_game_id uuid, _cards integer[]) TO service_role;
GRANT EXECUTE ON FUNCTION public.rami_request_refund(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rami_request_refund(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.rami_set_ready(_game_id uuid, _ready boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rami_set_ready(_game_id uuid, _ready boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.rami_start(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rami_start(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.rami_start_solo_bot(_max_players integer, _difficulty text, _joker_mode text) TO anon;
GRANT EXECUTE ON FUNCTION public.rami_start_solo_bot(_max_players integer, _difficulty text, _joker_mode text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rami_start_solo_bot(_max_players integer, _difficulty text, _joker_mode text) TO service_role;
GRANT EXECUTE ON FUNCTION public.rami_tick(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rami_tick(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.rami_validate_hand(_game_id uuid, _layout jsonb, _discard_card integer) TO anon;
GRANT EXECUTE ON FUNCTION public.rami_validate_hand(_game_id uuid, _layout jsonb, _discard_card integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rami_validate_hand(_game_id uuid, _layout jsonb, _discard_card integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.request_password_reset(_contact text, _type text) TO anon;
GRANT EXECUTE ON FUNCTION public.request_password_reset(_contact text, _type text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_password_reset(_contact text, _type text) TO service_role;
GRANT EXECUTE ON FUNCTION public.request_phone_verification(_phone text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_phone_verification(_phone text) TO service_role;
GRANT EXECUTE ON FUNCTION public.request_withdrawal(_amount numeric, _method text, _user_phone text, _recipient_name text) TO anon;
GRANT EXECUTE ON FUNCTION public.request_withdrawal(_amount numeric, _method text, _user_phone text, _recipient_name text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_withdrawal(_amount numeric, _method text, _user_phone text, _recipient_name text) TO service_role;
GRANT EXECUTE ON FUNCTION public.resolve_room_code(_code text) TO anon;
GRANT EXECUTE ON FUNCTION public.resolve_room_code(_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_room_code(_code text) TO service_role;
GRANT EXECUTE ON FUNCTION public.run_finance_tests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.run_finance_tests() TO service_role;
GRANT EXECUTE ON FUNCTION public.send_game_invite(_recipient_id uuid, _slug text, _game_id uuid, _sender_name text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_game_invite(_recipient_id uuid, _slug text, _game_id uuid, _sender_name text) TO service_role;
GRANT EXECUTE ON FUNCTION public.spectate_join(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.spectate_join(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.spectate_leave(_game_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.spectate_leave(_game_id uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.submit_bug_report(_category text, _message text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_bug_report(_category text, _message text) TO service_role;
GRANT EXECUTE ON FUNCTION public.super_player_set_dice(_game_id uuid, _slot integer, _value integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.super_player_set_dice(_game_id uuid, _dice integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.super_player_set_dice(_game_id uuid, _dice integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.super_player_set_dice(_game_id uuid, _slot integer, _value integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_profile_is_admin() TO anon;
GRANT EXECUTE ON FUNCTION public.sync_profile_is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_profile_is_admin() TO service_role;
GRANT EXECUTE ON FUNCTION public.tick_all_games() TO authenticated;
GRANT EXECUTE ON FUNCTION public.tick_all_games() TO service_role;
GRANT EXECUTE ON FUNCTION public.toggle_spectator_chat(_game_id uuid, _enabled boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_spectator_chat(_game_id uuid, _enabled boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.touch_announcements_updated_at() TO anon;
GRANT EXECUTE ON FUNCTION public.touch_announcements_updated_at() TO authenticated;
GRANT EXECUTE ON FUNCTION public.touch_announcements_updated_at() TO service_role;
GRANT EXECUTE ON FUNCTION public.touch_game_configs() TO anon;
GRANT EXECUTE ON FUNCTION public.touch_game_configs() TO authenticated;
GRANT EXECUTE ON FUNCTION public.touch_game_configs() TO service_role;
GRANT EXECUTE ON FUNCTION public.tournament_engine(_tid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.tournament_engine(_tid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.tournament_engine(_tid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.tournament_engine_all() TO anon;
GRANT EXECUTE ON FUNCTION public.tournament_engine_all() TO authenticated;
GRANT EXECUTE ON FUNCTION public.tournament_engine_all() TO service_role;
GRANT EXECUTE ON FUNCTION public.tournament_register(_tid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.tournament_register(_tid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.tournament_register(_tid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.tournament_sim_report(_tid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.tournament_sim_report(_tid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.tournament_sim_report(_tid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.tournament_state(_tid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.tournament_state(_tid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.tournament_state(_tid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.tournament_unregister(_tid uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.tournament_unregister(_tid uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.tournament_unregister(_tid uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_game_state(_game_id uuid, _state jsonb, _current_turn integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_game_state(_game_id uuid, _state jsonb, _current_turn integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_updated_at_column() TO anon;
GRANT EXECUTE ON FUNCTION public.update_updated_at_column() TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_updated_at_column() TO service_role;
GRANT EXECUTE ON FUNCTION public.verify_phone_code(_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_phone_code(_code text) TO service_role;
GRANT EXECUTE ON FUNCTION public.weekly_top_winners(_limit integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.weekly_top_winners(_limit integer) TO service_role;

-- ═══════════ 0011_rls_policies.sql ═══════════
-- 0011_rls_policies.sql
-- Row Level Security et politiques d'accès

ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_action_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_aliases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_broadcasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_email_otps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_lockouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_login_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_login_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_persona ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_user_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assistant_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.balance_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billiard_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billiard_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_mutes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_presence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chess_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chess_moves ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cms_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deposits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.domino_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.domino_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fanorona_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fanorona_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_spectators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.house_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ludo_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ludo_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.money_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.password_reset_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.petanque_boules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.petanque_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.petanque_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_game_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poker_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poker_hand_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poker_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poker_tournament_blind_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poker_tournament_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rami_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rami_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_fraud_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_entrants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_pool_entrants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_pools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawal_debts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS achievements_public_read ON public.achievements; CREATE POLICY achievements_public_read ON public.achievements AS PERMISSIVE FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS action_logs_admin_read ON public.admin_action_logs; CREATE POLICY action_logs_admin_read ON public.admin_action_logs AS PERMISSIVE FOR SELECT TO authenticated USING (is_admin());
DROP POLICY IF EXISTS aliases_own ON public.admin_aliases; CREATE POLICY aliases_own ON public.admin_aliases AS PERMISSIVE FOR ALL TO authenticated USING ((admin_id = auth.uid())) WITH CHECK ((admin_id = auth.uid()));
DROP POLICY IF EXISTS broadcasts_read_active ON public.admin_broadcasts; CREATE POLICY broadcasts_read_active ON public.admin_broadcasts AS PERMISSIVE FOR SELECT TO authenticated USING (((deleted_at IS NULL) OR is_admin()));
DROP POLICY IF EXISTS admin_email_otps_self ON public.admin_email_otps; CREATE POLICY admin_email_otps_self ON public.admin_email_otps AS PERMISSIVE FOR SELECT TO authenticated USING ((user_id = auth.uid()));
DROP POLICY IF EXISTS admin_lockouts_admins_read ON public.admin_lockouts; CREATE POLICY admin_lockouts_admins_read ON public.admin_lockouts AS PERMISSIVE FOR SELECT TO authenticated USING ((has_role(auth.uid(), 'admin'::app_role) OR (user_id = auth.uid())));
DROP POLICY IF EXISTS admin_login_approvals_read ON public.admin_login_approvals; CREATE POLICY admin_login_approvals_read ON public.admin_login_approvals AS PERMISSIVE FOR SELECT TO authenticated USING (((requesting_user_id = auth.uid()) OR has_role(auth.uid(), 'admin'::app_role)));
DROP POLICY IF EXISTS admin_login_attempts_admins_read ON public.admin_login_attempts; CREATE POLICY admin_login_attempts_admins_read ON public.admin_login_attempts AS PERMISSIVE FOR SELECT TO authenticated USING (has_role(auth.uid(), 'admin'::app_role));
DROP POLICY IF EXISTS admin_logs_read ON public.admin_logs; CREATE POLICY admin_logs_read ON public.admin_logs AS PERMISSIVE FOR SELECT TO authenticated USING (is_admin());
DROP POLICY IF EXISTS persona_own ON public.admin_persona; CREATE POLICY persona_own ON public.admin_persona AS PERMISSIVE FOR ALL TO "unknown (OID=0)" USING ((admin_id = auth.uid())) WITH CHECK ((admin_id = auth.uid()));
DROP POLICY IF EXISTS admin_sessions_self_read ON public.admin_sessions; CREATE POLICY admin_sessions_self_read ON public.admin_sessions AS PERMISSIVE FOR SELECT TO authenticated USING (((user_id = auth.uid()) OR has_role(auth.uid(), 'admin'::app_role)));
DROP POLICY IF EXISTS dm_read ON public.admin_user_messages; CREATE POLICY dm_read ON public.admin_user_messages AS PERMISSIVE FOR SELECT TO authenticated USING (((auth.uid() = user_id) OR is_admin()));
DROP POLICY IF EXISTS dm_user_insert ON public.admin_user_messages; CREATE POLICY dm_user_insert ON public.admin_user_messages AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((auth.uid() = user_id) AND (from_admin = false)));
DROP POLICY IF EXISTS dm_user_update ON public.admin_user_messages; CREATE POLICY dm_user_update ON public.admin_user_messages AS PERMISSIVE FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));
DROP POLICY IF EXISTS announcements_admin_delete ON public.announcements; CREATE POLICY announcements_admin_delete ON public.announcements AS PERMISSIVE FOR DELETE TO authenticated USING (is_admin());
DROP POLICY IF EXISTS announcements_admin_insert ON public.announcements; CREATE POLICY announcements_admin_insert ON public.announcements AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (is_admin());
DROP POLICY IF EXISTS announcements_admin_update ON public.announcements; CREATE POLICY announcements_admin_update ON public.announcements AS PERMISSIVE FOR UPDATE TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS announcements_read_active_or_admin ON public.announcements; CREATE POLICY announcements_read_active_or_admin ON public.announcements AS PERMISSIVE FOR SELECT TO authenticated USING (((active = true) OR is_admin()));
DROP POLICY IF EXISTS settings_admin_full_read ON public.app_settings; CREATE POLICY settings_admin_full_read ON public.app_settings AS PERMISSIVE FOR SELECT TO authenticated USING (is_admin());
DROP POLICY IF EXISTS settings_admin_update ON public.app_settings; CREATE POLICY settings_admin_update ON public.app_settings AS PERMISSIVE FOR UPDATE TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS settings_read_auth ON public.app_settings; CREATE POLICY settings_read_auth ON public.app_settings AS PERMISSIVE FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "own assistant msgs delete" ON public.assistant_messages; CREATE POLICY "own assistant msgs delete" ON public.assistant_messages AS PERMISSIVE FOR DELETE TO authenticated USING ((user_id = auth.uid()));
DROP POLICY IF EXISTS "own assistant msgs insert" ON public.assistant_messages; CREATE POLICY "own assistant msgs insert" ON public.assistant_messages AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((user_id = auth.uid()));
DROP POLICY IF EXISTS "own assistant msgs read" ON public.assistant_messages; CREATE POLICY "own assistant msgs read" ON public.assistant_messages AS PERMISSIVE FOR SELECT TO authenticated USING ((user_id = auth.uid()));
DROP POLICY IF EXISTS audit_admin_read ON public.balance_audit_log; CREATE POLICY audit_admin_read ON public.balance_audit_log AS PERMISSIVE FOR SELECT TO authenticated USING (has_role(auth.uid(), 'admin'::app_role));
DROP POLICY IF EXISTS billiard_games_insert ON public.billiard_games; CREATE POLICY billiard_games_insert ON public.billiard_games AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((auth.uid() = host_id));
DROP POLICY IF EXISTS billiard_games_select ON public.billiard_games; CREATE POLICY billiard_games_select ON public.billiard_games AS PERMISSIVE FOR SELECT TO authenticated USING ((((status = ANY (ARRAY['open'::text, 'playing'::text])) AND (is_private = false)) OR (host_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM billiard_participants p
  WHERE ((p.game_id = billiard_games.id) AND (p.user_id = auth.uid())))) OR is_admin()));
DROP POLICY IF EXISTS billiard_games_update ON public.billiard_games; CREATE POLICY billiard_games_update ON public.billiard_games AS PERMISSIVE FOR UPDATE TO authenticated USING (((host_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM billiard_participants p
  WHERE ((p.game_id = billiard_games.id) AND (p.user_id = auth.uid())))) OR is_admin())) WITH CHECK (((host_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM billiard_participants p
  WHERE ((p.game_id = billiard_games.id) AND (p.user_id = auth.uid())))) OR is_admin()));
DROP POLICY IF EXISTS billiard_participants_insert ON public.billiard_participants; CREATE POLICY billiard_participants_insert ON public.billiard_participants AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));
DROP POLICY IF EXISTS billiard_participants_select ON public.billiard_participants; CREATE POLICY billiard_participants_select ON public.billiard_participants AS PERMISSIVE FOR SELECT TO authenticated USING (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM billiard_games g
  WHERE ((g.id = billiard_participants.game_id) AND (((g.status = ANY (ARRAY['open'::text, 'playing'::text])) AND (g.is_private = false)) OR (g.host_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM billiard_participants p2
          WHERE ((p2.game_id = g.id) AND (p2.user_id = auth.uid())))))))) OR is_admin()));
DROP POLICY IF EXISTS billiard_participants_update ON public.billiard_participants; CREATE POLICY billiard_participants_update ON public.billiard_participants AS PERMISSIVE FOR UPDATE TO authenticated USING (((user_id = auth.uid()) OR is_admin())) WITH CHECK (((user_id = auth.uid()) OR is_admin()));
DROP POLICY IF EXISTS bug_reports_admin_update ON public.bug_reports; CREATE POLICY bug_reports_admin_update ON public.bug_reports AS PERMISSIVE FOR UPDATE TO "unknown (OID=0)" USING (is_admin());
DROP POLICY IF EXISTS bug_reports_insert ON public.bug_reports; CREATE POLICY bug_reports_insert ON public.bug_reports AS PERMISSIVE FOR INSERT TO "unknown (OID=0)" WITH CHECK ((auth.uid() = user_id));
DROP POLICY IF EXISTS bug_reports_select ON public.bug_reports; CREATE POLICY bug_reports_select ON public.bug_reports AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (((auth.uid() = user_id) OR is_admin()));
DROP POLICY IF EXISTS chat_members_delete ON public.chat_members; CREATE POLICY chat_members_delete ON public.chat_members AS PERMISSIVE FOR DELETE TO authenticated USING (((user_id = auth.uid()) OR is_admin()));
DROP POLICY IF EXISTS chat_members_insert ON public.chat_members; CREATE POLICY chat_members_insert ON public.chat_members AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((user_id = auth.uid()) AND (is_admin() OR (EXISTS ( SELECT 1
   FROM chat_rooms r
  WHERE ((r.id = chat_members.room_id) AND (r.type = 'global'::text) AND (r.joinable = true) AND (r.enabled = true)))))));
DROP POLICY IF EXISTS chat_members_read ON public.chat_members; CREATE POLICY chat_members_read ON public.chat_members AS PERMISSIVE FOR SELECT TO authenticated USING (((user_id = auth.uid()) OR is_admin() OR (EXISTS ( SELECT 1
   FROM chat_members m
  WHERE ((m.room_id = chat_members.room_id) AND (m.user_id = auth.uid()))))));
DROP POLICY IF EXISTS chat_messages_delete ON public.chat_messages; CREATE POLICY chat_messages_delete ON public.chat_messages AS PERMISSIVE FOR DELETE TO authenticated USING (((user_id = auth.uid()) OR is_admin()));
DROP POLICY IF EXISTS chat_messages_insert ON public.chat_messages; CREATE POLICY chat_messages_insert ON public.chat_messages AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM chat_rooms r
  WHERE ((r.id = chat_messages.room_id) AND (r.enabled = true) AND ((r.type = 'global'::text) OR ((r.type = 'dm'::text) AND ((r.dm_user_a = auth.uid()) OR (r.dm_user_b = auth.uid()))) OR ((r.type = 'game'::text) AND (_is_game_participant(r.game_id, auth.uid()) OR (EXISTS ( SELECT 1
           FROM game_spectators s
          WHERE ((s.game_id = r.game_id) AND (s.user_id = auth.uid())))))) OR is_admin()))))));
DROP POLICY IF EXISTS chat_messages_select ON public.chat_messages; CREATE POLICY chat_messages_select ON public.chat_messages AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM chat_rooms r
  WHERE ((r.id = chat_messages.room_id) AND ((r.type = 'global'::text) OR ((r.type = 'dm'::text) AND ((r.dm_user_a = auth.uid()) OR (r.dm_user_b = auth.uid()))) OR ((r.type = 'game'::text) AND (_is_game_participant(r.game_id, auth.uid()) OR (EXISTS ( SELECT 1
           FROM game_spectators s
          WHERE ((s.game_id = r.game_id) AND (s.user_id = auth.uid())))))) OR is_admin())))));
DROP POLICY IF EXISTS chat_messages_update_own ON public.chat_messages; CREATE POLICY chat_messages_update_own ON public.chat_messages AS PERMISSIVE FOR UPDATE TO authenticated USING (((user_id = auth.uid()) OR is_admin())) WITH CHECK (((user_id = auth.uid()) OR is_admin()));
DROP POLICY IF EXISTS chat_mutes_read ON public.chat_mutes; CREATE POLICY chat_mutes_read ON public.chat_mutes AS PERMISSIVE FOR SELECT TO authenticated USING (((user_id = auth.uid()) OR is_admin()));
DROP POLICY IF EXISTS chat_presence_select ON public.chat_presence; CREATE POLICY chat_presence_select ON public.chat_presence AS PERMISSIVE FOR SELECT TO authenticated USING (((user_id = auth.uid()) OR is_admin() OR ((typing_room IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM chat_rooms r
  WHERE ((r.id = chat_presence.typing_room) AND ((r.type = 'global'::text) OR ((r.type = 'dm'::text) AND ((r.dm_user_a = auth.uid()) OR (r.dm_user_b = auth.uid()))) OR ((r.type = 'game'::text) AND (_is_game_participant(r.game_id, auth.uid()) OR (EXISTS ( SELECT 1
           FROM game_spectators s
          WHERE ((s.game_id = r.game_id) AND (s.user_id = auth.uid()))))))))))) OR ((current_game IS NOT NULL) AND (_is_game_participant(current_game, auth.uid()) OR (EXISTS ( SELECT 1
   FROM game_spectators s
  WHERE ((s.game_id = chat_presence.current_game) AND (s.user_id = auth.uid()))))))));
DROP POLICY IF EXISTS chat_presence_update ON public.chat_presence; CREATE POLICY chat_presence_update ON public.chat_presence AS PERMISSIVE FOR UPDATE TO authenticated USING ((user_id = auth.uid())) WITH CHECK ((user_id = auth.uid()));
DROP POLICY IF EXISTS chat_presence_upsert ON public.chat_presence; CREATE POLICY chat_presence_upsert ON public.chat_presence AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((user_id = auth.uid()));
DROP POLICY IF EXISTS chat_reactions_del ON public.chat_reactions; CREATE POLICY chat_reactions_del ON public.chat_reactions AS PERMISSIVE FOR DELETE TO authenticated USING ((user_id = auth.uid()));
DROP POLICY IF EXISTS chat_reactions_ins ON public.chat_reactions; CREATE POLICY chat_reactions_ins ON public.chat_reactions AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((user_id = auth.uid()));
DROP POLICY IF EXISTS chat_reactions_select ON public.chat_reactions; CREATE POLICY chat_reactions_select ON public.chat_reactions AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM (chat_messages m
     JOIN chat_rooms r ON ((r.id = m.room_id)))
  WHERE ((m.id = chat_reactions.message_id) AND ((r.type = 'global'::text) OR ((r.type = 'dm'::text) AND ((r.dm_user_a = auth.uid()) OR (r.dm_user_b = auth.uid()))) OR ((r.type = 'game'::text) AND (_is_game_participant(r.game_id, auth.uid()) OR (EXISTS ( SELECT 1
           FROM game_spectators s
          WHERE ((s.game_id = r.game_id) AND (s.user_id = auth.uid())))))) OR is_admin())))));
DROP POLICY IF EXISTS chat_rooms_admin_write ON public.chat_rooms; CREATE POLICY chat_rooms_admin_write ON public.chat_rooms AS PERMISSIVE FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS chat_rooms_select ON public.chat_rooms; CREATE POLICY chat_rooms_select ON public.chat_rooms AS PERMISSIVE FOR SELECT TO authenticated USING (((type = 'global'::text) OR ((type = 'dm'::text) AND ((dm_user_a = auth.uid()) OR (dm_user_b = auth.uid()))) OR ((type = 'game'::text) AND (_is_game_participant(game_id, auth.uid()) OR (EXISTS ( SELECT 1
   FROM game_spectators s
  WHERE ((s.game_id = chat_rooms.game_id) AND (s.user_id = auth.uid())))))) OR is_admin()));
DROP POLICY IF EXISTS chess_games_select ON public.chess_games; CREATE POLICY chess_games_select ON public.chess_games AS PERMISSIVE FOR SELECT TO authenticated, anon USING (((NOT is_private) OR (auth.uid() = white_id) OR (auth.uid() = black_id) OR (auth.uid() = host_id)));
DROP POLICY IF EXISTS chess_moves_select ON public.chess_moves; CREATE POLICY chess_moves_select ON public.chess_moves AS PERMISSIVE FOR SELECT TO authenticated, anon USING ((EXISTS ( SELECT 1
   FROM chess_games g
  WHERE ((g.id = chess_moves.game_id) AND ((NOT g.is_private) OR (auth.uid() = g.white_id) OR (auth.uid() = g.black_id) OR (auth.uid() = g.host_id))))));
DROP POLICY IF EXISTS "cms_content admin write" ON public.cms_content; CREATE POLICY "cms_content admin write" ON public.cms_content AS PERMISSIVE FOR ALL TO authenticated USING (has_role(auth.uid(), 'admin'::app_role)) WITH CHECK (has_role(auth.uid(), 'admin'::app_role));
DROP POLICY IF EXISTS "cms_content read all" ON public.cms_content; CREATE POLICY "cms_content read all" ON public.cms_content AS PERMISSIVE FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS deposits_insert ON public.deposits; CREATE POLICY deposits_insert ON public.deposits AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((auth.uid() = user_id) AND (status = 'pending'::tx_status)));
DROP POLICY IF EXISTS deposits_select ON public.deposits; CREATE POLICY deposits_select ON public.deposits AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (((auth.uid() = user_id) OR is_admin()));
DROP POLICY IF EXISTS domino_games_select ON public.domino_games; CREATE POLICY domino_games_select ON public.domino_games AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING ((((status = ANY (ARRAY['open'::game_status, 'playing'::game_status])) AND (is_private = false)) OR (host_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM domino_participants p
  WHERE ((p.game_id = domino_games.id) AND (p.user_id = auth.uid())))) OR is_admin()));
DROP POLICY IF EXISTS domino_parts_select ON public.domino_participants; CREATE POLICY domino_parts_select ON public.domino_participants AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (_domino_visible(game_id));
DROP POLICY IF EXISTS fanorona_games_select ON public.fanorona_games; CREATE POLICY fanorona_games_select ON public.fanorona_games AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING ((((status = ANY (ARRAY['open'::game_status, 'playing'::game_status])) AND (is_private = false)) OR (host_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM fanorona_participants p
  WHERE ((p.game_id = fanorona_games.id) AND (p.user_id = auth.uid())))) OR is_admin()));
DROP POLICY IF EXISTS fanorona_parts_select ON public.fanorona_participants; CREATE POLICY fanorona_parts_select ON public.fanorona_participants AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (_fanorona_visible(game_id));
DROP POLICY IF EXISTS friendships_delete_involved ON public.friendships; CREATE POLICY friendships_delete_involved ON public.friendships AS PERMISSIVE FOR DELETE TO authenticated USING (((auth.uid() = requester_id) OR (auth.uid() = addressee_id)));
DROP POLICY IF EXISTS friendships_insert_own ON public.friendships; CREATE POLICY friendships_insert_own ON public.friendships AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((auth.uid() = requester_id));
DROP POLICY IF EXISTS friendships_select_involved ON public.friendships; CREATE POLICY friendships_select_involved ON public.friendships AS PERMISSIVE FOR SELECT TO authenticated USING (((auth.uid() = requester_id) OR (auth.uid() = addressee_id)));
DROP POLICY IF EXISTS friendships_update_involved ON public.friendships; CREATE POLICY friendships_update_involved ON public.friendships AS PERMISSIVE FOR UPDATE TO authenticated USING (((auth.uid() = requester_id) OR (auth.uid() = addressee_id))) WITH CHECK (((auth.uid() = requester_id) OR (auth.uid() = addressee_id)));
DROP POLICY IF EXISTS "game_configs admin write" ON public.game_configs; CREATE POLICY "game_configs admin write" ON public.game_configs AS PERMISSIVE FOR ALL TO authenticated USING (has_role(auth.uid(), 'admin'::app_role)) WITH CHECK (has_role(auth.uid(), 'admin'::app_role));
DROP POLICY IF EXISTS "game_configs readable by all" ON public.game_configs; CREATE POLICY "game_configs readable by all" ON public.game_configs AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (true);
DROP POLICY IF EXISTS gi_delete_involved ON public.game_invitations; CREATE POLICY gi_delete_involved ON public.game_invitations AS PERMISSIVE FOR DELETE TO authenticated USING (((auth.uid() = sender_id) OR (auth.uid() = receiver_id)));
DROP POLICY IF EXISTS gi_insert_own ON public.game_invitations; CREATE POLICY gi_insert_own ON public.game_invitations AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((auth.uid() = sender_id) AND (EXISTS ( SELECT 1
   FROM friendships f
  WHERE ((f.status = 'accepted'::text) AND (((f.requester_id = auth.uid()) AND (f.addressee_id = game_invitations.receiver_id)) OR ((f.addressee_id = auth.uid()) AND (f.requester_id = game_invitations.receiver_id))))))));
DROP POLICY IF EXISTS gi_select_involved ON public.game_invitations; CREATE POLICY gi_select_involved ON public.game_invitations AS PERMISSIVE FOR SELECT TO authenticated USING (((auth.uid() = sender_id) OR (auth.uid() = receiver_id)));
DROP POLICY IF EXISTS gi_update_involved ON public.game_invitations; CREATE POLICY gi_update_involved ON public.game_invitations AS PERMISSIVE FOR UPDATE TO authenticated USING (((auth.uid() = sender_id) OR (auth.uid() = receiver_id))) WITH CHECK (((auth.uid() = sender_id) OR (auth.uid() = receiver_id)));
DROP POLICY IF EXISTS spectators_delete ON public.game_spectators; CREATE POLICY spectators_delete ON public.game_spectators AS PERMISSIVE FOR DELETE TO authenticated USING (((auth.uid() = user_id) OR is_admin()));
DROP POLICY IF EXISTS spectators_insert ON public.game_spectators; CREATE POLICY spectators_insert ON public.game_spectators AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));
DROP POLICY IF EXISTS spectators_select ON public.game_spectators; CREATE POLICY spectators_select ON public.game_spectators AS PERMISSIVE FOR SELECT TO authenticated USING (_game_visible(game_id));
DROP POLICY IF EXISTS house_ledger_admin_read ON public.house_ledger; CREATE POLICY house_ledger_admin_read ON public.house_ledger AS PERMISSIVE FOR SELECT TO authenticated USING (is_admin());
DROP POLICY IF EXISTS games_select ON public.ludo_games; CREATE POLICY games_select ON public.ludo_games AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING ((((status = ANY (ARRAY['open'::game_status, 'playing'::game_status])) AND (is_private = false)) OR (host_id = auth.uid()) OR _is_game_participant(id, auth.uid()) OR is_admin()));
DROP POLICY IF EXISTS parts_select ON public.ludo_participants; CREATE POLICY parts_select ON public.ludo_participants AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (_game_visible(game_id));
DROP POLICY IF EXISTS money_offers_admin_all ON public.money_offers; CREATE POLICY money_offers_admin_all ON public.money_offers AS PERMISSIVE FOR ALL TO authenticated USING (has_role(auth.uid(), 'admin'::app_role)) WITH CHECK (has_role(auth.uid(), 'admin'::app_role));
DROP POLICY IF EXISTS money_offers_public_read ON public.money_offers; CREATE POLICY money_offers_public_read ON public.money_offers AS PERMISSIVE FOR SELECT TO authenticated, anon USING ((active = true));
DROP POLICY IF EXISTS notif_delete_own ON public.notifications; CREATE POLICY notif_delete_own ON public.notifications AS PERMISSIVE FOR DELETE TO authenticated USING ((user_id = auth.uid()));
DROP POLICY IF EXISTS notif_read_own ON public.notifications; CREATE POLICY notif_read_own ON public.notifications AS PERMISSIVE FOR SELECT TO authenticated USING ((user_id = auth.uid()));
DROP POLICY IF EXISTS notif_update_own ON public.notifications; CREATE POLICY notif_update_own ON public.notifications AS PERMISSIVE FOR UPDATE TO authenticated USING ((user_id = auth.uid())) WITH CHECK ((user_id = auth.uid()));
DROP POLICY IF EXISTS notifications_admin_insert ON public.notifications; CREATE POLICY notifications_admin_insert ON public.notifications AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (is_admin());
DROP POLICY IF EXISTS prr_admin_read ON public.password_reset_requests; CREATE POLICY prr_admin_read ON public.password_reset_requests AS PERMISSIVE FOR SELECT TO authenticated USING (is_admin());
DROP POLICY IF EXISTS prr_admin_update ON public.password_reset_requests; CREATE POLICY prr_admin_update ON public.password_reset_requests AS PERMISSIVE FOR UPDATE TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS prr_insert_any ON public.password_reset_requests; CREATE POLICY prr_insert_any ON public.password_reset_requests AS PERMISSIVE FOR INSERT TO anon, authenticated WITH CHECK ((((length(contact) >= 5) AND (length(contact) <= 200)) AND ((contact ~* '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$'::text) OR (contact ~ '^\+?[0-9 ()\-]{7,20}$'::text))));
DROP POLICY IF EXISTS petanque_boules_select ON public.petanque_boules; CREATE POLICY petanque_boules_select ON public.petanque_boules AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (((EXISTS ( SELECT 1
   FROM petanque_games g
  WHERE ((g.id = petanque_boules.game_id) AND (((g.status = ANY (ARRAY['open'::text, 'playing'::text])) AND (g.is_private = false)) OR (g.creator_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM petanque_participants p2
          WHERE ((p2.game_id = g.id) AND (p2.user_id = auth.uid())))))))) OR is_admin()));
DROP POLICY IF EXISTS petanque_games_select ON public.petanque_games; CREATE POLICY petanque_games_select ON public.petanque_games AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING ((((status = ANY (ARRAY['open'::text, 'playing'::text])) AND (is_private = false)) OR (creator_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM petanque_participants p
  WHERE ((p.game_id = petanque_games.id) AND (p.user_id = auth.uid())))) OR is_admin()));
DROP POLICY IF EXISTS petanque_participants_select ON public.petanque_participants; CREATE POLICY petanque_participants_select ON public.petanque_participants AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (((EXISTS ( SELECT 1
   FROM petanque_games g
  WHERE ((g.id = petanque_participants.game_id) AND (((g.status = ANY (ARRAY['open'::text, 'playing'::text])) AND (g.is_private = false)) OR (g.creator_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM petanque_participants p2
          WHERE ((p2.game_id = g.id) AND (p2.user_id = auth.uid())))))))) OR is_admin()));
DROP POLICY IF EXISTS player_achievements_read_all ON public.player_achievements; CREATE POLICY player_achievements_read_all ON public.player_achievements AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (true);
DROP POLICY IF EXISTS pgstats_select ON public.player_game_stats; CREATE POLICY pgstats_select ON public.player_game_stats AS PERMISSIVE FOR SELECT TO authenticated USING (((user_id = auth.uid()) OR is_admin()));
DROP POLICY IF EXISTS poker_games_read ON public.poker_games; CREATE POLICY poker_games_read ON public.poker_games AS PERMISSIVE FOR SELECT TO authenticated USING ((((status = ANY (ARRAY['open'::text, 'playing'::text])) AND (is_private = false)) OR (created_by = auth.uid()) OR (EXISTS ( SELECT 1
   FROM poker_players pp
  WHERE ((pp.game_id = poker_games.id) AND (pp.user_id = auth.uid())))) OR is_admin()));
DROP POLICY IF EXISTS poker_hh_read ON public.poker_hand_history; CREATE POLICY poker_hh_read ON public.poker_hand_history AS PERMISSIVE FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1
   FROM poker_players pp
  WHERE ((pp.game_id = poker_hand_history.game_id) AND (pp.user_id = auth.uid())))) OR is_admin()));
DROP POLICY IF EXISTS poker_players_read_public_cols ON public.poker_players; CREATE POLICY poker_players_read_public_cols ON public.poker_players AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (true);
DROP POLICY IF EXISTS poker_blinds_admin_write ON public.poker_tournament_blind_levels; CREATE POLICY poker_blinds_admin_write ON public.poker_tournament_blind_levels AS PERMISSIVE FOR ALL TO "unknown (OID=0)" USING (has_role(auth.uid(), 'admin'::app_role)) WITH CHECK (has_role(auth.uid(), 'admin'::app_role));
DROP POLICY IF EXISTS poker_blinds_read ON public.poker_tournament_blind_levels; CREATE POLICY poker_blinds_read ON public.poker_tournament_blind_levels AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (true);
DROP POLICY IF EXISTS poker_ttables_admin_write ON public.poker_tournament_tables; CREATE POLICY poker_ttables_admin_write ON public.poker_tournament_tables AS PERMISSIVE FOR ALL TO "unknown (OID=0)" USING (has_role(auth.uid(), 'admin'::app_role)) WITH CHECK (has_role(auth.uid(), 'admin'::app_role));
DROP POLICY IF EXISTS poker_ttables_read ON public.poker_tournament_tables; CREATE POLICY poker_ttables_read ON public.poker_tournament_tables AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (true);
DROP POLICY IF EXISTS profiles_premium_admin_update ON public.profiles; CREATE POLICY profiles_premium_admin_update ON public.profiles AS PERMISSIVE FOR UPDATE TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS profiles_self_insert ON public.profiles; CREATE POLICY profiles_self_insert ON public.profiles AS PERMISSIVE FOR INSERT TO "unknown (OID=0)" WITH CHECK ((auth.uid() = id));
DROP POLICY IF EXISTS profiles_self_select ON public.profiles; CREATE POLICY profiles_self_select ON public.profiles AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (((auth.uid() = id) OR is_admin()));
DROP POLICY IF EXISTS profiles_self_update_safe ON public.profiles; CREATE POLICY profiles_self_update_safe ON public.profiles AS PERMISSIVE FOR UPDATE TO authenticated USING ((auth.uid() = id)) WITH CHECK (((auth.uid() = id) AND (balance_ar = ( SELECT p.balance_ar
   FROM profiles p
  WHERE (p.id = auth.uid()))) AND (banned = ( SELECT p.banned
   FROM profiles p
  WHERE (p.id = auth.uid()))) AND (status = ( SELECT p.status
   FROM profiles p
  WHERE (p.id = auth.uid()))) AND (unique_code = ( SELECT p.unique_code
   FROM profiles p
  WHERE (p.id = auth.uid()))) AND (referral_code = ( SELECT p.referral_code
   FROM profiles p
  WHERE (p.id = auth.uid()))) AND (phone_verified = ( SELECT p.phone_verified
   FROM profiles p
  WHERE (p.id = auth.uid()))) AND (referral_unlocked = ( SELECT p.referral_unlocked
   FROM profiles p
  WHERE (p.id = auth.uid()))) AND (COALESCE((referred_by)::text, ''::text) = COALESCE(( SELECT (p.referred_by)::text AS referred_by
   FROM profiles p
  WHERE (p.id = auth.uid())), ''::text)) AND (COALESCE(phone_verification_code, ''::text) = COALESCE(( SELECT p.phone_verification_code
   FROM profiles p
  WHERE (p.id = auth.uid())), ''::text)) AND (COALESCE(phone_verification_code_hash, ''::text) = COALESCE(( SELECT p.phone_verification_code_hash
   FROM profiles p
  WHERE (p.id = auth.uid())), ''::text)) AND (COALESCE((phone_verification_requested_at)::text, ''::text) = COALESCE(( SELECT (p.phone_verification_requested_at)::text AS phone_verification_requested_at
   FROM profiles p
  WHERE (p.id = auth.uid())), ''::text)) AND ((( SELECT p.phone_verified
   FROM profiles p
  WHERE (p.id = auth.uid())) = false) OR (COALESCE(phone, ''::text) = COALESCE(( SELECT p.phone
   FROM profiles p
  WHERE (p.id = auth.uid())), ''::text)))));
DROP POLICY IF EXISTS rami_games_select ON public.rami_games; CREATE POLICY rami_games_select ON public.rami_games AS PERMISSIVE FOR SELECT TO authenticated USING ((((status = ANY (ARRAY['open'::text, 'playing'::text])) AND (is_private = false)) OR (created_by = auth.uid()) OR (EXISTS ( SELECT 1
   FROM rami_participants p
  WHERE ((p.game_id = rami_games.id) AND (p.user_id = auth.uid())))) OR is_admin()));
DROP POLICY IF EXISTS rami_participants_select ON public.rami_participants; CREATE POLICY rami_participants_select ON public.rami_participants AS PERMISSIVE FOR SELECT TO authenticated USING (_rami_visible(game_id));
DROP POLICY IF EXISTS ref_events_own ON public.referral_events; CREATE POLICY ref_events_own ON public.referral_events AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (((referrer_id = auth.uid()) OR (referee_id = auth.uid())));
DROP POLICY IF EXISTS ref_fraud_admin ON public.referral_fraud_flags; CREATE POLICY ref_fraud_admin ON public.referral_fraud_flags AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (is_admin());
DROP POLICY IF EXISTS referral_settings_admin_all ON public.referral_settings; CREATE POLICY referral_settings_admin_all ON public.referral_settings AS PERMISSIVE FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS support_insert ON public.support_messages; CREATE POLICY support_insert ON public.support_messages AS PERMISSIVE FOR INSERT TO "unknown (OID=0)" WITH CHECK ((auth.uid() = user_id));
DROP POLICY IF EXISTS support_select ON public.support_messages; CREATE POLICY support_select ON public.support_messages AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (((auth.uid() = user_id) OR is_admin()));
DROP POLICY IF EXISTS te_admin ON public.tournament_entrants; CREATE POLICY te_admin ON public.tournament_entrants AS PERMISSIVE FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS te_read ON public.tournament_entrants; CREATE POLICY te_read ON public.tournament_entrants AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (true);
DROP POLICY IF EXISTS tm_admin ON public.tournament_matches; CREATE POLICY tm_admin ON public.tournament_matches AS PERMISSIVE FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS tm_read ON public.tournament_matches; CREATE POLICY tm_read ON public.tournament_matches AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (true);
DROP POLICY IF EXISTS tpe_admin ON public.tournament_pool_entrants; CREATE POLICY tpe_admin ON public.tournament_pool_entrants AS PERMISSIVE FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS tpe_read ON public.tournament_pool_entrants; CREATE POLICY tpe_read ON public.tournament_pool_entrants AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (true);
DROP POLICY IF EXISTS tp_admin ON public.tournament_pools; CREATE POLICY tp_admin ON public.tournament_pools AS PERMISSIVE FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS tp_read ON public.tournament_pools; CREATE POLICY tp_read ON public.tournament_pools AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (true);
DROP POLICY IF EXISTS t_admin ON public.tournaments; CREATE POLICY t_admin ON public.tournaments AS PERMISSIVE FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS t_read ON public.tournaments; CREATE POLICY t_read ON public.tournaments AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (true);
DROP POLICY IF EXISTS transactions_admin_insert ON public.transactions; CREATE POLICY transactions_admin_insert ON public.transactions AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (is_admin());
DROP POLICY IF EXISTS tx_select ON public.transactions; CREATE POLICY tx_select ON public.transactions AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (((auth.uid() = user_id) OR is_admin()));
DROP POLICY IF EXISTS roles_self_select ON public.user_roles; CREATE POLICY roles_self_select ON public.user_roles AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (((auth.uid() = user_id) OR is_admin()));
DROP POLICY IF EXISTS own_or_admin_read ON public.withdrawal_debts; CREATE POLICY own_or_admin_read ON public.withdrawal_debts AS PERMISSIVE FOR SELECT TO authenticated USING (((auth.uid() = user_id) OR is_admin()));
DROP POLICY IF EXISTS withdrawals_insert ON public.withdrawals; CREATE POLICY withdrawals_insert ON public.withdrawals AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((auth.uid() = user_id) AND (status = 'pending'::tx_status)));
DROP POLICY IF EXISTS withdrawals_select ON public.withdrawals; CREATE POLICY withdrawals_select ON public.withdrawals AS PERMISSIVE FOR SELECT TO "unknown (OID=0)" USING (((auth.uid() = user_id) OR is_admin()));

-- ═══════════ 0012_realtime.sql ═══════════
-- 0012_realtime.sql
-- Realtime : publication et replica identity

DO $$ BEGIN CREATE PUBLICATION supabase_realtime; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;
ALTER TABLE public.chat_presence REPLICA IDENTITY FULL;
ALTER TABLE public.chat_reactions REPLICA IDENTITY FULL;
ALTER TABLE public.chess_games REPLICA IDENTITY FULL;
ALTER TABLE public.domino_games REPLICA IDENTITY FULL;
ALTER TABLE public.domino_participants REPLICA IDENTITY FULL;
ALTER TABLE public.fanorona_games REPLICA IDENTITY FULL;
ALTER TABLE public.fanorona_participants REPLICA IDENTITY FULL;
ALTER TABLE public.ludo_games REPLICA IDENTITY FULL;
ALTER TABLE public.ludo_participants REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;
ALTER TABLE public.petanque_boules REPLICA IDENTITY FULL;
ALTER TABLE public.petanque_games REPLICA IDENTITY FULL;
ALTER TABLE public.petanque_participants REPLICA IDENTITY FULL;
ALTER TABLE public.poker_games REPLICA IDENTITY FULL;
ALTER TABLE public.poker_players REPLICA IDENTITY FULL;
ALTER TABLE public.profiles REPLICA IDENTITY FULL;
ALTER TABLE public.rami_games REPLICA IDENTITY FULL;
ALTER TABLE public.rami_participants REPLICA IDENTITY FULL;
ALTER TABLE public.tournament_entrants REPLICA IDENTITY FULL;
ALTER TABLE public.tournament_matches REPLICA IDENTITY FULL;
ALTER TABLE public.tournament_pool_entrants REPLICA IDENTITY FULL;
ALTER TABLE public.tournament_pools REPLICA IDENTITY FULL;
ALTER TABLE public.tournaments REPLICA IDENTITY FULL;
ALTER TABLE public.transactions REPLICA IDENTITY FULL;

ALTER PUBLICATION supabase_realtime ADD TABLE public.admin_broadcasts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.announcements;
ALTER PUBLICATION supabase_realtime ADD TABLE public.app_settings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_members;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_mutes;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_presence;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_reactions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chess_games;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chess_moves;
ALTER PUBLICATION supabase_realtime ADD TABLE public.domino_games;
ALTER PUBLICATION supabase_realtime ADD TABLE public.domino_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.fanorona_games;
ALTER PUBLICATION supabase_realtime ADD TABLE public.fanorona_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.game_invitations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.game_spectators;
ALTER PUBLICATION supabase_realtime ADD TABLE public.ludo_games;
ALTER PUBLICATION supabase_realtime ADD TABLE public.ludo_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.petanque_boules;
ALTER PUBLICATION supabase_realtime ADD TABLE public.petanque_games;
ALTER PUBLICATION supabase_realtime ADD TABLE public.petanque_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.poker_games;
ALTER PUBLICATION supabase_realtime ADD TABLE public.poker_players;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.rami_games;
ALTER PUBLICATION supabase_realtime ADD TABLE public.rami_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.tournament_entrants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.tournament_matches;
ALTER PUBLICATION supabase_realtime ADD TABLE public.tournament_pool_entrants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.tournament_pools;
ALTER PUBLICATION supabase_realtime ADD TABLE public.tournaments;
ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;

-- ═══════════ 0013_storage.sql ═══════════
-- 0013_storage.sql
-- Buckets de stockage et politiques associées

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('avatars', 'avatars', 't', NULL, NULL) ON CONFLICT (id) DO UPDATE SET public=EXCLUDED.public, file_size_limit=EXCLUDED.file_size_limit, allowed_mime_types=EXCLUDED.allowed_mime_types;
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('chat', 'chat', 'f', NULL, NULL) ON CONFLICT (id) DO UPDATE SET public=EXCLUDED.public, file_size_limit=EXCLUDED.file_size_limit, allowed_mime_types=EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Avatars owner can list" ON storage.objects; CREATE POLICY "Avatars owner can list" ON storage.objects FOR SELECT TO authenticated USING (((bucket_id = 'avatars'::text) AND ((auth.uid())::text = (storage.foldername(name))[1])));
DROP POLICY IF EXISTS "Users delete own avatar" ON storage.objects; CREATE POLICY "Users delete own avatar" ON storage.objects FOR DELETE TO "unknown (OID=0)" USING (((bucket_id = 'avatars'::text) AND ((auth.uid())::text = (storage.foldername(name))[1])));
DROP POLICY IF EXISTS "Users update own avatar" ON storage.objects; CREATE POLICY "Users update own avatar" ON storage.objects FOR UPDATE TO "unknown (OID=0)" USING (((bucket_id = 'avatars'::text) AND ((auth.uid())::text = (storage.foldername(name))[1])));
DROP POLICY IF EXISTS "Users upload own avatar" ON storage.objects; CREATE POLICY "Users upload own avatar" ON storage.objects FOR INSERT TO "unknown (OID=0)" WITH CHECK (((bucket_id = 'avatars'::text) AND ((auth.uid())::text = (storage.foldername(name))[1])));
DROP POLICY IF EXISTS avatars_chat_user_insert ON storage.objects; CREATE POLICY avatars_chat_user_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK (((bucket_id = ANY (ARRAY['avatars'::text, 'chat'::text])) AND ((auth.uid())::text = (storage.foldername(name))[1])));
DROP POLICY IF EXISTS chat_owner_delete ON storage.objects; CREATE POLICY chat_owner_delete ON storage.objects FOR DELETE TO authenticated USING (((bucket_id = 'chat'::text) AND ((auth.uid())::text = (storage.foldername(name))[1])));
DROP POLICY IF EXISTS chat_owner_read ON storage.objects; CREATE POLICY chat_owner_read ON storage.objects FOR SELECT TO authenticated USING (((bucket_id = 'chat'::text) AND ((auth.uid())::text = (storage.foldername(name))[1])));

-- ═══════════ 0014_cron_jobs.sql ═══════════
-- 0014_cron_jobs.sql
-- Tâches planifiées (pg_cron)
-- Note : le schéma `cron` n'est pas lisible depuis l'export automatique.
-- Ce fichier reconstruit les jobs à partir des migrations du projet.
-- À exécuter EN DERNIER, une fois toutes les fonctions créées.

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Nettoyage des anciens jobs éventuels
DO $$
DECLARE j RECORD;
BEGIN
  FOR j IN SELECT jobname FROM cron.job
           WHERE jobname IN ('tick-all-games','tick-all-games-20s','tick-all-games-40s',
                             'ludo_tick_all','domino_tick_all','tournament_engine_all')
  LOOP
    PERFORM cron.unschedule(j.jobname);
  END LOOP;
END $$;

-- Moteur global des parties (timeouts, reprise, annulation auto) — toutes les 20 s
SELECT cron.schedule('tick-all-games',     '* * * * *', $$SELECT public.tick_all_games();$$);
SELECT cron.schedule('tick-all-games-20s', '* * * * *', $$SELECT pg_sleep(20); SELECT public.tick_all_games();$$);
SELECT cron.schedule('tick-all-games-40s', '* * * * *', $$SELECT pg_sleep(40); SELECT public.tick_all_games();$$);

-- Bots + timers Ludo et Domino — toutes les 5 s
SELECT cron.schedule('ludo_tick_all',   '5 seconds', $$SELECT public.ludo_tick_all();$$);
SELECT cron.schedule('domino_tick_all', '5 seconds', $$SELECT public.domino_tick_all();$$);

-- Moteur de tournoi (lancement des matchs, forfaits, avancement des rounds) — toutes les 15 s
SELECT cron.schedule('tournament_engine_all', '15 seconds', $$SELECT public.tournament_engine_all();$$);

-- Vérification :
--   SELECT jobname, schedule, active FROM cron.job ORDER BY jobname;
--   SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 20;

