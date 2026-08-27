export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      activity_entries: {
        Row: {
          activity_type: string
          calories_burned: number | null
          created_at: string
          duration_minutes: number | null
          id: string
          source: string
          started_at: string
          steps: number | null
          updated_at: string
          user_id: string
        }
        Insert: {
          activity_type: string
          calories_burned?: number | null
          created_at?: string
          duration_minutes?: number | null
          id?: string
          source?: string
          started_at?: string
          steps?: number | null
          updated_at?: string
          user_id: string
        }
        Update: {
          activity_type?: string
          calories_burned?: number | null
          created_at?: string
          duration_minutes?: number | null
          id?: string
          source?: string
          started_at?: string
          steps?: number | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "activity_entries_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_entries_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_usage_logs: {
        Row: {
          completion_tokens: number
          created_at: string
          id: string
          model_used: string
          prompt_tokens: number
          user_id: string
        }
        Insert: {
          completion_tokens?: number
          created_at?: string
          id?: string
          model_used: string
          prompt_tokens?: number
          user_id: string
        }
        Update: {
          completion_tokens?: number
          created_at?: string
          id?: string
          model_used?: string
          prompt_tokens?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_usage_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_usage_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_logs: {
        Row: {
          action: string
          actor_id: string | null
          created_at: string
          id: string
          ip_hash: string | null
          metadata: Json | null
          request_metadata: Json | null
          target_id: string | null
          target_type: string
          updated_at: string
        }
        Insert: {
          action: string
          actor_id?: string | null
          created_at?: string
          id?: string
          ip_hash?: string | null
          metadata?: Json | null
          request_metadata?: Json | null
          target_id?: string | null
          target_type: string
          updated_at?: string
        }
        Update: {
          action?: string
          actor_id?: string | null
          created_at?: string
          id?: string
          ip_hash?: string | null
          metadata?: Json | null
          request_metadata?: Json | null
          target_id?: string | null
          target_type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "audit_logs_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_logs_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      blog_posts: {
        Row: {
          author_user_id: string | null
          brand: string
          content: string
          created_at: string
          excerpt: string | null
          id: string
          published_at: string | null
          slug: string
          status: string
          title: string
          updated_at: string
        }
        Insert: {
          author_user_id?: string | null
          brand?: string
          content: string
          created_at?: string
          excerpt?: string | null
          id?: string
          published_at?: string | null
          slug: string
          status?: string
          title: string
          updated_at?: string
        }
        Update: {
          author_user_id?: string | null
          brand?: string
          content?: string
          created_at?: string
          excerpt?: string | null
          id?: string
          published_at?: string | null
          slug?: string
          status?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "blog_posts_author_user_id_fkey"
            columns: ["author_user_id"]
            isOneToOne: false
            referencedRelation: "vera_users"
            referencedColumns: ["id"]
          },
        ]
      }
      body_measurements: {
        Row: {
          created_at: string
          id: string
          measured_at: string
          measurement_type: Database["public"]["Enums"]["measurement_type"]
          unit: string
          updated_at: string
          user_id: string
          value: number
        }
        Insert: {
          created_at?: string
          id?: string
          measured_at?: string
          measurement_type: Database["public"]["Enums"]["measurement_type"]
          unit: string
          updated_at?: string
          user_id: string
          value: number
        }
        Update: {
          created_at?: string
          id?: string
          measured_at?: string
          measurement_type?: Database["public"]["Enums"]["measurement_type"]
          unit?: string
          updated_at?: string
          user_id?: string
          value?: number
        }
        Relationships: [
          {
            foreignKeyName: "body_measurements_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "body_measurements_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      consent_records: {
        Row: {
          consent_type: Database["public"]["Enums"]["consent_type"]
          created_at: string
          granted: boolean
          id: string
          updated_at: string
          user_id: string
          version: string
        }
        Insert: {
          consent_type: Database["public"]["Enums"]["consent_type"]
          created_at?: string
          granted: boolean
          id?: string
          updated_at?: string
          user_id: string
          version: string
        }
        Update: {
          consent_type?: Database["public"]["Enums"]["consent_type"]
          created_at?: string
          granted?: boolean
          id?: string
          updated_at?: string
          user_id?: string
          version?: string
        }
        Relationships: [
          {
            foreignKeyName: "consent_records_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "consent_records_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      daily_nutrition_summaries: {
        Row: {
          calories: number
          carbs_g: number
          created_at: string
          date: string
          fat_g: number
          fiber_g: number
          id: string
          meal_count: number
          protein_g: number
          updated_at: string
          user_id: string
          water_ml: number
        }
        Insert: {
          calories?: number
          carbs_g?: number
          created_at?: string
          date: string
          fat_g?: number
          fiber_g?: number
          id?: string
          meal_count?: number
          protein_g?: number
          updated_at?: string
          user_id: string
          water_ml?: number
        }
        Update: {
          calories?: number
          carbs_g?: number
          created_at?: string
          date?: string
          fat_g?: number
          fiber_g?: number
          id?: string
          meal_count?: number
          protein_g?: number
          updated_at?: string
          user_id?: string
          water_ml?: number
        }
        Relationships: [
          {
            foreignKeyName: "daily_nutrition_summaries_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "daily_nutrition_summaries_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      data_deletion_requests: {
        Row: {
          completed_at: string | null
          created_at: string
          id: string
          reason: string | null
          requested_at: string
          scheduled_for: string
          status: Database["public"]["Enums"]["deletion_request_status"]
          updated_at: string
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          created_at?: string
          id?: string
          reason?: string | null
          requested_at?: string
          scheduled_for?: string
          status?: Database["public"]["Enums"]["deletion_request_status"]
          updated_at?: string
          user_id: string
        }
        Update: {
          completed_at?: string | null
          created_at?: string
          id?: string
          reason?: string | null
          requested_at?: string
          scheduled_for?: string
          status?: Database["public"]["Enums"]["deletion_request_status"]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "data_deletion_requests_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "data_deletion_requests_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      data_exports: {
        Row: {
          artifact_path: string | null
          completed_at: string | null
          created_at: string
          expires_at: string | null
          id: string
          requested_at: string
          status: Database["public"]["Enums"]["data_export_status"]
          updated_at: string
          user_id: string
        }
        Insert: {
          artifact_path?: string | null
          completed_at?: string | null
          created_at?: string
          expires_at?: string | null
          id?: string
          requested_at?: string
          status?: Database["public"]["Enums"]["data_export_status"]
          updated_at?: string
          user_id: string
        }
        Update: {
          artifact_path?: string | null
          completed_at?: string | null
          created_at?: string
          expires_at?: string | null
          id?: string
          requested_at?: string
          status?: Database["public"]["Enums"]["data_export_status"]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "data_exports_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "data_exports_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      esim_orders: {
        Row: {
          airalo_order_code: string
          airalo_order_id: number
          country_code: string
          country_name: string
          created_at: string
          data_text: string
          direct_apple_install_url: string | null
          iccid: string
          id: string
          lpa: string
          matching_id: string
          package_id: string
          package_title: string
          price: number
          qrcode: string
          qrcode_url: string | null
          status: string
          user_id: string | null
          validity_days: number
        }
        Insert: {
          airalo_order_code: string
          airalo_order_id: number
          country_code: string
          country_name: string
          created_at?: string
          data_text: string
          direct_apple_install_url?: string | null
          iccid: string
          id?: string
          lpa: string
          matching_id: string
          package_id: string
          package_title: string
          price: number
          qrcode: string
          qrcode_url?: string | null
          status?: string
          user_id?: string | null
          validity_days: number
        }
        Update: {
          airalo_order_code?: string
          airalo_order_id?: number
          country_code?: string
          country_name?: string
          created_at?: string
          data_text?: string
          direct_apple_install_url?: string | null
          iccid?: string
          id?: string
          lpa?: string
          matching_id?: string
          package_id?: string
          package_title?: string
          price?: number
          qrcode?: string
          qrcode_url?: string | null
          status?: string
          user_id?: string | null
          validity_days?: number
        }
        Relationships: [
          {
            foreignKeyName: "esim_orders_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "vera_users"
            referencedColumns: ["id"]
          },
        ]
      }
      film_invites: {
        Row: {
          created_at: string
          expires_at: string | null
          film_id: string
          id: string
          token: string
        }
        Insert: {
          created_at?: string
          expires_at?: string | null
          film_id: string
          id?: string
          token: string
        }
        Update: {
          created_at?: string
          expires_at?: string | null
          film_id?: string
          id?: string
          token?: string
        }
        Relationships: [
          {
            foreignKeyName: "film_invites_film_id_fkey"
            columns: ["film_id"]
            isOneToOne: false
            referencedRelation: "films"
            referencedColumns: ["id"]
          },
        ]
      }
      film_members: {
        Row: {
          display_name: string
          film_id: string
          guest_token: string | null
          id: string
          joined_at: string
          shots_used: number
          user_id: string | null
        }
        Insert: {
          display_name: string
          film_id: string
          guest_token?: string | null
          id?: string
          joined_at?: string
          shots_used?: number
          user_id?: string | null
        }
        Update: {
          display_name?: string
          film_id?: string
          guest_token?: string | null
          id?: string
          joined_at?: string
          shots_used?: number
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "film_members_film_id_fkey"
            columns: ["film_id"]
            isOneToOne: false
            referencedRelation: "films"
            referencedColumns: ["id"]
          },
        ]
      }
      film_shots: {
        Row: {
          captured_at: string
          film_id: string
          id: string
          is_revealed: boolean
          member_id: string
          storage_path: string
        }
        Insert: {
          captured_at?: string
          film_id: string
          id?: string
          is_revealed?: boolean
          member_id: string
          storage_path: string
        }
        Update: {
          captured_at?: string
          film_id?: string
          id?: string
          is_revealed?: boolean
          member_id?: string
          storage_path?: string
        }
        Relationships: [
          {
            foreignKeyName: "film_shots_film_id_fkey"
            columns: ["film_id"]
            isOneToOne: false
            referencedRelation: "films"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "film_shots_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "film_members"
            referencedColumns: ["id"]
          },
        ]
      }
      films: {
        Row: {
          created_at: string
          creator_id: string
          id: string
          member_limit: number
          name: string
          reveal_at: string
          shot_limit: number
          status: string
        }
        Insert: {
          created_at?: string
          creator_id: string
          id?: string
          member_limit?: number
          name: string
          reveal_at: string
          shot_limit?: number
          status?: string
        }
        Update: {
          created_at?: string
          creator_id?: string
          id?: string
          member_limit?: number
          name?: string
          reveal_at?: string
          shot_limit?: number
          status?: string
        }
        Relationships: []
      }
      food_external_mappings: {
        Row: {
          created_at: string
          external_id: string
          food_id: string
          food_source_id: string
          id: string
          last_synced_at: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          external_id: string
          food_id: string
          food_source_id: string
          id?: string
          last_synced_at?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          external_id?: string
          food_id?: string
          food_source_id?: string
          id?: string
          last_synced_at?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "food_external_mappings_food_id_fkey"
            columns: ["food_id"]
            isOneToOne: false
            referencedRelation: "foods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "food_external_mappings_food_source_id_fkey"
            columns: ["food_source_id"]
            isOneToOne: false
            referencedRelation: "food_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      food_log_items: {
        Row: {
          ai_estimated: boolean
          calories: number
          carbs_g: number
          confidence: number | null
          created_at: string
          fat_g: number
          fiber_g: number
          food_id: string | null
          food_log_id: string
          food_nutrition_version_id: string | null
          grams: number | null
          id: string
          name: string
          protein_g: number
          quantity: number
          sodium_mg: number
          sugar_g: number
          unit: string
          updated_at: string
        }
        Insert: {
          ai_estimated?: boolean
          calories: number
          carbs_g?: number
          confidence?: number | null
          created_at?: string
          fat_g?: number
          fiber_g?: number
          food_id?: string | null
          food_log_id: string
          food_nutrition_version_id?: string | null
          grams?: number | null
          id?: string
          name: string
          protein_g?: number
          quantity: number
          sodium_mg?: number
          sugar_g?: number
          unit: string
          updated_at?: string
        }
        Update: {
          ai_estimated?: boolean
          calories?: number
          carbs_g?: number
          confidence?: number | null
          created_at?: string
          fat_g?: number
          fiber_g?: number
          food_id?: string | null
          food_log_id?: string
          food_nutrition_version_id?: string | null
          grams?: number | null
          id?: string
          name?: string
          protein_g?: number
          quantity?: number
          sodium_mg?: number
          sugar_g?: number
          unit?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "food_log_items_food_id_fkey"
            columns: ["food_id"]
            isOneToOne: false
            referencedRelation: "foods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "food_log_items_food_log_id_fkey"
            columns: ["food_log_id"]
            isOneToOne: false
            referencedRelation: "food_logs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "food_log_items_food_nutrition_version_id_fkey"
            columns: ["food_nutrition_version_id"]
            isOneToOne: false
            referencedRelation: "food_nutrition_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "food_log_items_version_food_fk"
            columns: ["food_nutrition_version_id", "food_id"]
            isOneToOne: false
            referencedRelation: "food_nutrition_versions"
            referencedColumns: ["id", "food_id"]
          },
        ]
      }
      food_logs: {
        Row: {
          created_at: string
          id: string
          logged_at: string
          meal_group_id: string | null
          notes: string | null
          photo_path: string | null
          source: Database["public"]["Enums"]["food_log_source"]
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          logged_at?: string
          meal_group_id?: string | null
          notes?: string | null
          photo_path?: string | null
          source?: Database["public"]["Enums"]["food_log_source"]
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          logged_at?: string
          meal_group_id?: string | null
          notes?: string | null
          photo_path?: string | null
          source?: Database["public"]["Enums"]["food_log_source"]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "food_logs_meal_group_id_fkey"
            columns: ["meal_group_id"]
            isOneToOne: false
            referencedRelation: "meal_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "food_logs_meal_group_user_fk"
            columns: ["meal_group_id", "user_id"]
            isOneToOne: false
            referencedRelation: "meal_groups"
            referencedColumns: ["id", "user_id"]
          },
          {
            foreignKeyName: "food_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "food_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      food_nutrition_versions: {
        Row: {
          change_reason: string
          changed_by: string | null
          created_at: string
          food_id: string
          id: string
          nutrition: Json
          updated_at: string
          version: number
        }
        Insert: {
          change_reason: string
          changed_by?: string | null
          created_at?: string
          food_id: string
          id?: string
          nutrition: Json
          updated_at?: string
          version: number
        }
        Update: {
          change_reason?: string
          changed_by?: string | null
          created_at?: string
          food_id?: string
          id?: string
          nutrition?: Json
          updated_at?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "food_nutrition_versions_changed_by_fkey"
            columns: ["changed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "food_nutrition_versions_changed_by_fkey"
            columns: ["changed_by"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "food_nutrition_versions_food_id_fkey"
            columns: ["food_id"]
            isOneToOne: false
            referencedRelation: "foods"
            referencedColumns: ["id"]
          },
        ]
      }
      food_servings: {
        Row: {
          created_at: string
          food_id: string
          grams: number
          id: string
          label: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          food_id: string
          grams: number
          id?: string
          label: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          food_id?: string
          grams?: number
          id?: string
          label?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "food_servings_food_id_fkey"
            columns: ["food_id"]
            isOneToOne: false
            referencedRelation: "foods"
            referencedColumns: ["id"]
          },
        ]
      }
      food_sources: {
        Row: {
          code: string
          created_at: string
          id: string
          is_active: boolean
          name: string
          priority: number
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          priority: number
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          priority?: number
          updated_at?: string
        }
        Relationships: []
      }
      foods: {
        Row: {
          barcode: string | null
          brand: string | null
          calories: number
          carbs_g: number
          created_at: string
          external_id: string
          fat_g: number
          fiber_g: number
          id: string
          metadata: Json
          name: string
          protein_g: number
          serving_size: number
          serving_unit: string
          sodium_mg: number
          source: string
          sugar_g: number
          updated_at: string
        }
        Insert: {
          barcode?: string | null
          brand?: string | null
          calories: number
          carbs_g?: number
          created_at?: string
          external_id: string
          fat_g?: number
          fiber_g?: number
          id?: string
          metadata?: Json
          name: string
          protein_g?: number
          serving_size: number
          serving_unit: string
          sodium_mg?: number
          source: string
          sugar_g?: number
          updated_at?: string
        }
        Update: {
          barcode?: string | null
          brand?: string | null
          calories?: number
          carbs_g?: number
          created_at?: string
          external_id?: string
          fat_g?: number
          fiber_g?: number
          id?: string
          metadata?: Json
          name?: string
          protein_g?: number
          serving_size?: number
          serving_unit?: string
          sodium_mg?: number
          source?: string
          sugar_g?: number
          updated_at?: string
        }
        Relationships: []
      }
      goal_milestones: {
        Row: {
          achieved_at: string | null
          created_at: string
          goal_id: string
          id: string
          target_value: number | null
          title: string
          updated_at: string
        }
        Insert: {
          achieved_at?: string | null
          created_at?: string
          goal_id: string
          id?: string
          target_value?: number | null
          title: string
          updated_at?: string
        }
        Update: {
          achieved_at?: string | null
          created_at?: string
          goal_id?: string
          id?: string
          target_value?: number | null
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "goal_milestones_goal_id_fkey"
            columns: ["goal_id"]
            isOneToOne: false
            referencedRelation: "goals"
            referencedColumns: ["id"]
          },
        ]
      }
      goal_targets: {
        Row: {
          created_at: string
          goal_id: string
          id: string
          metric: string
          period: Database["public"]["Enums"]["goal_period"]
          target_value: number
          unit: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          goal_id: string
          id?: string
          metric: string
          period?: Database["public"]["Enums"]["goal_period"]
          target_value: number
          unit?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          goal_id?: string
          id?: string
          metric?: string
          period?: Database["public"]["Enums"]["goal_period"]
          target_value?: number
          unit?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "goal_targets_goal_id_fkey"
            columns: ["goal_id"]
            isOneToOne: false
            referencedRelation: "goals"
            referencedColumns: ["id"]
          },
        ]
      }
      goals: {
        Row: {
          created_at: string
          description: string | null
          id: string
          start_date: string | null
          starting_value: number | null
          status: Database["public"]["Enums"]["goal_status"]
          target_date: string | null
          target_value: number | null
          title: string
          type: string
          unit: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          start_date?: string | null
          starting_value?: number | null
          status?: Database["public"]["Enums"]["goal_status"]
          target_date?: string | null
          target_value?: number | null
          title: string
          type: string
          unit?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          start_date?: string | null
          starting_value?: number | null
          status?: Database["public"]["Enums"]["goal_status"]
          target_date?: string | null
          target_value?: number | null
          title?: string
          type?: string
          unit?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "goals_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "goals_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      idempotency_keys: {
        Row: {
          created_at: string
          expires_at: string
          id: string
          key: string
          request_hash: string
          response: Json | null
          scope: Database["public"]["Enums"]["idempotency_scope"]
          status: Database["public"]["Enums"]["idempotency_status"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          expires_at: string
          id?: string
          key: string
          request_hash: string
          response?: Json | null
          scope: Database["public"]["Enums"]["idempotency_scope"]
          status?: Database["public"]["Enums"]["idempotency_status"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          expires_at?: string
          id?: string
          key?: string
          request_hash?: string
          response?: Json | null
          scope?: Database["public"]["Enums"]["idempotency_scope"]
          status?: Database["public"]["Enums"]["idempotency_status"]
          updated_at?: string
        }
        Relationships: []
      }
      meal_groups: {
        Row: {
          created_at: string
          id: string
          logged_at: string
          meal_type: Database["public"]["Enums"]["meal_type"]
          name: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          logged_at?: string
          meal_type?: Database["public"]["Enums"]["meal_type"]
          name: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          logged_at?: string
          meal_type?: Database["public"]["Enums"]["meal_type"]
          name?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "meal_groups_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "meal_groups_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      mood_entries: {
        Row: {
          created_at: string
          energy_score: number | null
          id: string
          mood_score: number
          notes: string | null
          recorded_at: string
          stress_score: number | null
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          energy_score?: number | null
          id?: string
          mood_score: number
          notes?: string | null
          recorded_at?: string
          stress_score?: number | null
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          energy_score?: number | null
          id?: string
          mood_score?: number
          notes?: string | null
          recorded_at?: string
          stress_score?: number | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "mood_entries_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "mood_entries_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      newsletter_campaign_deliveries: {
        Row: {
          campaign_id: string
          created_at: string
          error: string | null
          id: string
          provider_message_id: string | null
          status: string
          subscriber_email: string
        }
        Insert: {
          campaign_id: string
          created_at?: string
          error?: string | null
          id?: string
          provider_message_id?: string | null
          status: string
          subscriber_email: string
        }
        Update: {
          campaign_id?: string
          created_at?: string
          error?: string | null
          id?: string
          provider_message_id?: string | null
          status?: string
          subscriber_email?: string
        }
        Relationships: [
          {
            foreignKeyName: "newsletter_campaign_deliveries_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "newsletter_campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      newsletter_campaigns: {
        Row: {
          body: string
          brand: string
          completed_at: string | null
          created_at: string
          created_by_user_id: string | null
          failed_count: number
          id: string
          provider: string | null
          sent_count: number
          started_at: string | null
          status: string
          subject: string
          target_count: number
          updated_at: string
        }
        Insert: {
          body: string
          brand?: string
          completed_at?: string | null
          created_at?: string
          created_by_user_id?: string | null
          failed_count?: number
          id?: string
          provider?: string | null
          sent_count?: number
          started_at?: string | null
          status?: string
          subject: string
          target_count?: number
          updated_at?: string
        }
        Update: {
          body?: string
          brand?: string
          completed_at?: string | null
          created_at?: string
          created_by_user_id?: string | null
          failed_count?: number
          id?: string
          provider?: string | null
          sent_count?: number
          started_at?: string | null
          status?: string
          subject?: string
          target_count?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "newsletter_campaigns_created_by_user_id_fkey"
            columns: ["created_by_user_id"]
            isOneToOne: false
            referencedRelation: "vera_users"
            referencedColumns: ["id"]
          },
        ]
      }
      newsletter_subscribers: {
        Row: {
          brand: string
          consent: boolean
          consent_at: string | null
          consent_text: string | null
          created_at: string
          email: string
          id: string
          ip_address: string | null
          locale: string
          referral_code: string
          referral_count: number
          referred_by: string | null
          source: string
          status: string
          unsubscribe_token: string
          updated_at: string
          user_agent: string | null
        }
        Insert: {
          brand?: string
          consent?: boolean
          consent_at?: string | null
          consent_text?: string | null
          created_at?: string
          email: string
          id?: string
          ip_address?: string | null
          locale?: string
          referral_code?: string
          referral_count?: number
          referred_by?: string | null
          source?: string
          status?: string
          unsubscribe_token?: string
          updated_at?: string
          user_agent?: string | null
        }
        Update: {
          brand?: string
          consent?: boolean
          consent_at?: string | null
          consent_text?: string | null
          created_at?: string
          email?: string
          id?: string
          ip_address?: string | null
          locale?: string
          referral_code?: string
          referral_count?: number
          referred_by?: string | null
          source?: string
          status?: string
          unsubscribe_token?: string
          updated_at?: string
          user_agent?: string | null
        }
        Relationships: []
      }
      profile_preferences: {
        Row: {
          ai_preferences: Json
          created_at: string
          dietary_preferences: Json
          fitness_preferences: Json
          notification_preferences: Json
          units: Database["public"]["Enums"]["units_system"]
          updated_at: string
          user_id: string
        }
        Insert: {
          ai_preferences?: Json
          created_at?: string
          dietary_preferences?: Json
          fitness_preferences?: Json
          notification_preferences?: Json
          units?: Database["public"]["Enums"]["units_system"]
          updated_at?: string
          user_id: string
        }
        Update: {
          ai_preferences?: Json
          created_at?: string
          dietary_preferences?: Json
          fitness_preferences?: Json
          notification_preferences?: Json
          units?: Database["public"]["Enums"]["units_system"]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "profile_preferences_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profile_preferences_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profile_privacy: {
        Row: {
          activity_visibility: Database["public"]["Enums"]["privacy_visibility"]
          coach_data_visibility: Database["public"]["Enums"]["privacy_visibility"]
          created_at: string
          nutrition_visibility: Database["public"]["Enums"]["privacy_visibility"]
          profile_visibility: Database["public"]["Enums"]["privacy_visibility"]
          progress_visibility: Database["public"]["Enums"]["privacy_visibility"]
          updated_at: string
          user_id: string
          weight_visibility: Database["public"]["Enums"]["privacy_visibility"]
        }
        Insert: {
          activity_visibility?: Database["public"]["Enums"]["privacy_visibility"]
          coach_data_visibility?: Database["public"]["Enums"]["privacy_visibility"]
          created_at?: string
          nutrition_visibility?: Database["public"]["Enums"]["privacy_visibility"]
          profile_visibility?: Database["public"]["Enums"]["privacy_visibility"]
          progress_visibility?: Database["public"]["Enums"]["privacy_visibility"]
          updated_at?: string
          user_id: string
          weight_visibility?: Database["public"]["Enums"]["privacy_visibility"]
        }
        Update: {
          activity_visibility?: Database["public"]["Enums"]["privacy_visibility"]
          coach_data_visibility?: Database["public"]["Enums"]["privacy_visibility"]
          created_at?: string
          nutrition_visibility?: Database["public"]["Enums"]["privacy_visibility"]
          profile_visibility?: Database["public"]["Enums"]["privacy_visibility"]
          progress_visibility?: Database["public"]["Enums"]["privacy_visibility"]
          updated_at?: string
          user_id?: string
          weight_visibility?: Database["public"]["Enums"]["privacy_visibility"]
        }
        Relationships: [
          {
            foreignKeyName: "profile_privacy_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profile_privacy_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          activity_level:
            | Database["public"]["Enums"]["profile_activity_level"]
            | null
          avatar_path: string | null
          bio: string | null
          created_at: string
          date_of_birth: string | null
          display_name: string | null
          email: string | null
          height_cm: number | null
          id: string
          is_public: boolean
          monthly_ai_credits: number
          onboarding_completed: boolean
          stripe_customer_id: string | null
          stripe_subscription_id: string | null
          subscription_status: string | null
          subscription_tier: string
          timezone: string | null
          updated_at: string
          username: string
        }
        Insert: {
          activity_level?:
            | Database["public"]["Enums"]["profile_activity_level"]
            | null
          avatar_path?: string | null
          bio?: string | null
          created_at?: string
          date_of_birth?: string | null
          display_name?: string | null
          email?: string | null
          height_cm?: number | null
          id: string
          is_public?: boolean
          monthly_ai_credits?: number
          onboarding_completed?: boolean
          stripe_customer_id?: string | null
          stripe_subscription_id?: string | null
          subscription_status?: string | null
          subscription_tier?: string
          timezone?: string | null
          updated_at?: string
          username: string
        }
        Update: {
          activity_level?:
            | Database["public"]["Enums"]["profile_activity_level"]
            | null
          avatar_path?: string | null
          bio?: string | null
          created_at?: string
          date_of_birth?: string | null
          display_name?: string | null
          email?: string | null
          height_cm?: number | null
          id?: string
          is_public?: boolean
          monthly_ai_credits?: number
          onboarding_completed?: boolean
          stripe_customer_id?: string | null
          stripe_subscription_id?: string | null
          subscription_status?: string | null
          subscription_tier?: string
          timezone?: string | null
          updated_at?: string
          username?: string
        }
        Relationships: []
      }
      progress_milestones: {
        Row: {
          achieved_at: string
          created_at: string
          description: string | null
          goal_id: string | null
          id: string
          title: string
          type: string
          updated_at: string
          user_id: string
        }
        Insert: {
          achieved_at?: string
          created_at?: string
          description?: string | null
          goal_id?: string | null
          id?: string
          title: string
          type: string
          updated_at?: string
          user_id: string
        }
        Update: {
          achieved_at?: string
          created_at?: string
          description?: string | null
          goal_id?: string | null
          id?: string
          title?: string
          type?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "progress_milestones_goal_id_fkey"
            columns: ["goal_id"]
            isOneToOne: false
            referencedRelation: "goals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "progress_milestones_goal_user_fk"
            columns: ["goal_id", "user_id"]
            isOneToOne: false
            referencedRelation: "goals"
            referencedColumns: ["id", "user_id"]
          },
          {
            foreignKeyName: "progress_milestones_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "progress_milestones_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      progress_photos: {
        Row: {
          caption: string | null
          captured_at: string
          created_at: string
          id: string
          storage_path: string
          updated_at: string
          user_id: string
          visibility: Database["public"]["Enums"]["privacy_visibility"]
        }
        Insert: {
          caption?: string | null
          captured_at?: string
          created_at?: string
          id?: string
          storage_path: string
          updated_at?: string
          user_id: string
          visibility?: Database["public"]["Enums"]["privacy_visibility"]
        }
        Update: {
          caption?: string | null
          captured_at?: string
          created_at?: string
          id?: string
          storage_path?: string
          updated_at?: string
          user_id?: string
          visibility?: Database["public"]["Enums"]["privacy_visibility"]
        }
        Relationships: [
          {
            foreignKeyName: "progress_photos_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "progress_photos_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      progress_videos: {
        Row: {
          caption: string | null
          captured_at: string
          created_at: string
          duration_seconds: number
          id: string
          storage_path: string
          updated_at: string
          user_id: string
          visibility: Database["public"]["Enums"]["privacy_visibility"]
        }
        Insert: {
          caption?: string | null
          captured_at?: string
          created_at?: string
          duration_seconds: number
          id?: string
          storage_path: string
          updated_at?: string
          user_id: string
          visibility?: Database["public"]["Enums"]["privacy_visibility"]
        }
        Update: {
          caption?: string | null
          captured_at?: string
          created_at?: string
          duration_seconds?: number
          id?: string
          storage_path?: string
          updated_at?: string
          user_id?: string
          visibility?: Database["public"]["Enums"]["privacy_visibility"]
        }
        Relationships: [
          {
            foreignKeyName: "progress_videos_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "progress_videos_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_blocks: {
        Row: {
          blocked_id: string
          blocker_id: string
          created_at: string
          updated_at: string
        }
        Insert: {
          blocked_id: string
          blocker_id: string
          created_at?: string
          updated_at?: string
        }
        Update: {
          blocked_id?: string
          blocker_id?: string
          created_at?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_blocks_blocked_id_fkey"
            columns: ["blocked_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_blocks_blocked_id_fkey"
            columns: ["blocked_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_blocks_blocker_id_fkey"
            columns: ["blocker_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_blocks_blocker_id_fkey"
            columns: ["blocker_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_devices: {
        Row: {
          app_version: string | null
          created_at: string
          id: string
          last_seen_at: string | null
          platform: string
          push_token: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          app_version?: string | null
          created_at?: string
          id?: string
          last_seen_at?: string | null
          platform: string
          push_token?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          app_version?: string | null
          created_at?: string
          id?: string
          last_seen_at?: string | null
          platform?: string
          push_token?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_devices_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_devices_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_orders: {
        Row: {
          amount: number
          created_at: string
          currency: string
          id: string
          order_type: string
          reference_code: string
          status: string
          user_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          currency?: string
          id?: string
          order_type: string
          reference_code: string
          status?: string
          user_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          currency?: string
          id?: string
          order_type?: string
          reference_code?: string
          status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_orders_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_orders_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      vera_users: {
        Row: {
          account_identifier: string
          created_at: string
          display_name: string | null
          email: string | null
          embedded_wallet_address: string | null
          id: string
          phone: string | null
          privy_user_id: string | null
          role: string
          social_provider: string | null
          social_user_id: string | null
          updated_at: string
        }
        Insert: {
          account_identifier: string
          created_at?: string
          display_name?: string | null
          email?: string | null
          embedded_wallet_address?: string | null
          id?: string
          phone?: string | null
          privy_user_id?: string | null
          role?: string
          social_provider?: string | null
          social_user_id?: string | null
          updated_at?: string
        }
        Update: {
          account_identifier?: string
          created_at?: string
          display_name?: string | null
          email?: string | null
          embedded_wallet_address?: string | null
          id?: string
          phone?: string | null
          privy_user_id?: string | null
          role?: string
          social_provider?: string | null
          social_user_id?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      webauthn_challenges: {
        Row: {
          challenge: string
          created_at: string
          email: string
          expires_at: string
          id: string
          purpose: string
        }
        Insert: {
          challenge: string
          created_at?: string
          email: string
          expires_at?: string
          id?: string
          purpose: string
        }
        Update: {
          challenge?: string
          created_at?: string
          email?: string
          expires_at?: string
          id?: string
          purpose?: string
        }
        Relationships: []
      }
      webauthn_credentials: {
        Row: {
          counter: number
          created_at: string
          credential_id: string
          device_label: string | null
          id: string
          last_used_at: string | null
          public_key: string
          transports: string[]
          user_id: string
        }
        Insert: {
          counter?: number
          created_at?: string
          credential_id: string
          device_label?: string | null
          id?: string
          last_used_at?: string | null
          public_key: string
          transports?: string[]
          user_id: string
        }
        Update: {
          counter?: number
          created_at?: string
          credential_id?: string
          device_label?: string | null
          id?: string
          last_used_at?: string | null
          public_key?: string
          transports?: string[]
          user_id?: string
        }
        Relationships: []
      }
      website_signups: {
        Row: {
          brand: string
          company: string | null
          created_at: string
          email: string
          full_name: string | null
          id: string
          message: string | null
          source: string
          status: string
          updated_at: string
        }
        Insert: {
          brand?: string
          company?: string | null
          created_at?: string
          email: string
          full_name?: string | null
          id?: string
          message?: string | null
          source?: string
          status?: string
          updated_at?: string
        }
        Update: {
          brand?: string
          company?: string | null
          created_at?: string
          email?: string
          full_name?: string | null
          id?: string
          message?: string | null
          source?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      weight_entries: {
        Row: {
          created_at: string
          id: string
          measured_at: string
          notes: string | null
          source: string
          updated_at: string
          user_id: string
          weight_kg: number
        }
        Insert: {
          created_at?: string
          id?: string
          measured_at?: string
          notes?: string | null
          source?: string
          updated_at?: string
          user_id: string
          weight_kg: number
        }
        Update: {
          created_at?: string
          id?: string
          measured_at?: string
          notes?: string | null
          source?: string
          updated_at?: string
          user_id?: string
          weight_kg?: number
        }
        Relationships: [
          {
            foreignKeyName: "weight_entries_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "weight_entries_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      public_profiles: {
        Row: {
          avatar_path: string | null
          bio: string | null
          created_at: string | null
          display_name: string | null
          id: string | null
          username: string | null
        }
        Insert: {
          avatar_path?: string | null
          bio?: string | null
          created_at?: string | null
          display_name?: string | null
          id?: string | null
          username?: string | null
        }
        Update: {
          avatar_path?: string | null
          bio?: string | null
          created_at?: string | null
          display_name?: string | null
          id?: string | null
          username?: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      increment_referral: { Args: { p_code: string }; Returns: undefined }
      is_platform_admin: { Args: never; Returns: boolean }
      owns_food_log: { Args: { p_food_log_id: string }; Returns: boolean }
      waitlist_position: { Args: { p_email: string }; Returns: number }
    }
    Enums: {
      consent_type: "terms" | "privacy" | "health_data" | "marketing"
      data_export_status:
        | "pending"
        | "processing"
        | "ready"
        | "expired"
        | "failed"
      deletion_request_status:
        | "pending"
        | "scheduled"
        | "processing"
        | "completed"
        | "cancelled"
      food_log_source: "manual" | "barcode" | "photo" | "ai" | "import"
      goal_period: "daily" | "weekly" | "monthly" | "overall"
      goal_status: "active" | "paused" | "completed" | "cancelled"
      idempotency_scope:
        | "payment"
        | "ai_write"
        | "booking"
        | "food_log"
        | "webhook"
        | "notification"
      idempotency_status: "pending" | "completed" | "failed"
      meal_type: "breakfast" | "lunch" | "dinner" | "snack" | "other"
      measurement_type:
        | "waist"
        | "chest"
        | "hips"
        | "thigh"
        | "arm"
        | "body_fat"
        | "muscle_mass"
      privacy_visibility: "private" | "followers" | "public" | "coach"
      profile_activity_level:
        | "sedentary"
        | "light"
        | "moderate"
        | "active"
        | "very_active"
      units_system: "metric" | "imperial"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      consent_type: ["terms", "privacy", "health_data", "marketing"],
      data_export_status: [
        "pending",
        "processing",
        "ready",
        "expired",
        "failed",
      ],
      deletion_request_status: [
        "pending",
        "scheduled",
        "processing",
        "completed",
        "cancelled",
      ],
      food_log_source: ["manual", "barcode", "photo", "ai", "import"],
      goal_period: ["daily", "weekly", "monthly", "overall"],
      goal_status: ["active", "paused", "completed", "cancelled"],
      idempotency_scope: [
        "payment",
        "ai_write",
        "booking",
        "food_log",
        "webhook",
        "notification",
      ],
      idempotency_status: ["pending", "completed", "failed"],
      meal_type: ["breakfast", "lunch", "dinner", "snack", "other"],
      measurement_type: [
        "waist",
        "chest",
        "hips",
        "thigh",
        "arm",
        "body_fat",
        "muscle_mass",
      ],
      privacy_visibility: ["private", "followers", "public", "coach"],
      profile_activity_level: [
        "sedentary",
        "light",
        "moderate",
        "active",
        "very_active",
      ],
      units_system: ["metric", "imperial"],
    },
  },
} as const

