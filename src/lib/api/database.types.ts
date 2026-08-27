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
      ai_conversations: {
        Row: {
          created_at: string
          id: string
          title: string | null
          type: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          title?: string | null
          type: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          title?: string | null
          type?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_conversations_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_conversations_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_feedback: {
        Row: {
          ai_request_id: string
          created_at: string
          feedback: string | null
          id: string
          rating: number | null
          updated_at: string
          user_id: string
        }
        Insert: {
          ai_request_id: string
          created_at?: string
          feedback?: string | null
          id?: string
          rating?: number | null
          updated_at?: string
          user_id: string
        }
        Update: {
          ai_request_id?: string
          created_at?: string
          feedback?: string | null
          id?: string
          rating?: number | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_feedback_ai_request_id_fkey"
            columns: ["ai_request_id"]
            isOneToOne: false
            referencedRelation: "ai_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_feedback_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_feedback_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_food_estimates: {
        Row: {
          confidence: number | null
          corrected_by_user: boolean
          created_at: string
          food_log_id: string | null
          id: string
          image_path: string | null
          model: string
          result: Json
          updated_at: string
          user_id: string
          verified: boolean
        }
        Insert: {
          confidence?: number | null
          corrected_by_user?: boolean
          created_at?: string
          food_log_id?: string | null
          id?: string
          image_path?: string | null
          model: string
          result: Json
          updated_at?: string
          user_id: string
          verified?: boolean
        }
        Update: {
          confidence?: number | null
          corrected_by_user?: boolean
          created_at?: string
          food_log_id?: string | null
          id?: string
          image_path?: string | null
          model?: string
          result?: Json
          updated_at?: string
          user_id?: string
          verified?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "ai_food_estimates_food_log_id_fkey"
            columns: ["food_log_id"]
            isOneToOne: false
            referencedRelation: "food_logs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_food_estimates_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_food_estimates_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_insights: {
        Row: {
          body: string
          created_at: string
          id: string
          model: string
          source_data: Json
          title: string
          type: string
          updated_at: string
          user_id: string
          valid_until: string | null
        }
        Insert: {
          body: string
          created_at?: string
          id?: string
          model: string
          source_data?: Json
          title: string
          type: string
          updated_at?: string
          user_id: string
          valid_until?: string | null
        }
        Update: {
          body?: string
          created_at?: string
          id?: string
          model?: string
          source_data?: Json
          title?: string
          type?: string
          updated_at?: string
          user_id?: string
          valid_until?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "ai_insights_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_insights_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_messages: {
        Row: {
          content: Json
          conversation_id: string
          created_at: string
          id: string
          model: string | null
          role: Database["public"]["Enums"]["ai_message_role"]
          updated_at: string
        }
        Insert: {
          content: Json
          conversation_id: string
          created_at?: string
          id?: string
          model?: string | null
          role: Database["public"]["Enums"]["ai_message_role"]
          updated_at?: string
        }
        Update: {
          content?: Json
          conversation_id?: string
          created_at?: string
          id?: string
          model?: string | null
          role?: Database["public"]["Enums"]["ai_message_role"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_messages_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "ai_conversations"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_model_runs: {
        Row: {
          ai_request_id: string
          created_at: string
          estimated_cost: number | null
          id: string
          input_tokens: number
          latency_ms: number | null
          model: string
          model_policy_version: string
          output_tokens: number
          prompt_version: string
          provider: string
          reasoning_tokens: number | null
          safety_policy_version: string
          structured_output_valid: boolean
          success: boolean
          tool_schema_version: string
          updated_at: string
        }
        Insert: {
          ai_request_id: string
          created_at?: string
          estimated_cost?: number | null
          id?: string
          input_tokens?: number
          latency_ms?: number | null
          model: string
          model_policy_version: string
          output_tokens?: number
          prompt_version: string
          provider: string
          reasoning_tokens?: number | null
          safety_policy_version: string
          structured_output_valid?: boolean
          success: boolean
          tool_schema_version: string
          updated_at?: string
        }
        Update: {
          ai_request_id?: string
          created_at?: string
          estimated_cost?: number | null
          id?: string
          input_tokens?: number
          latency_ms?: number | null
          model?: string
          model_policy_version?: string
          output_tokens?: number
          prompt_version?: string
          provider?: string
          reasoning_tokens?: number | null
          safety_policy_version?: string
          structured_output_valid?: boolean
          success?: boolean
          tool_schema_version?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_model_runs_ai_request_id_fkey"
            columns: ["ai_request_id"]
            isOneToOne: false
            referencedRelation: "ai_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_recommendations: {
        Row: {
          created_at: string
          dismissed_at: string | null
          id: string
          model: string
          reason: string
          recommendation_type: string
          score: number
          target_id: string | null
          title: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          dismissed_at?: string | null
          id?: string
          model: string
          reason: string
          recommendation_type: string
          score: number
          target_id?: string | null
          title: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          dismissed_at?: string | null
          id?: string
          model?: string
          reason?: string
          recommendation_type?: string
          score?: number
          target_id?: string | null
          title?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_recommendations_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_recommendations_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_requests: {
        Row: {
          completed_at: string | null
          created_at: string
          fallback_used: boolean
          id: string
          model_requested: string | null
          model_used: string | null
          request_id: string
          status: Database["public"]["Enums"]["ai_request_status"]
          task: string
          updated_at: string
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          created_at?: string
          fallback_used?: boolean
          id?: string
          model_requested?: string | null
          model_used?: string | null
          request_id: string
          status?: Database["public"]["Enums"]["ai_request_status"]
          task: string
          updated_at?: string
          user_id: string
        }
        Update: {
          completed_at?: string | null
          created_at?: string
          fallback_used?: boolean
          id?: string
          model_requested?: string | null
          model_used?: string | null
          request_id?: string
          status?: Database["public"]["Enums"]["ai_request_status"]
          task?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_requests_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_requests_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_tool_calls: {
        Row: {
          ai_request_id: string
          arguments: Json
          created_at: string
          id: string
          result: Json | null
          success: boolean
          tool_name: string
          updated_at: string
        }
        Insert: {
          ai_request_id: string
          arguments?: Json
          created_at?: string
          id?: string
          result?: Json | null
          success: boolean
          tool_name: string
          updated_at?: string
        }
        Update: {
          ai_request_id?: string
          arguments?: Json
          created_at?: string
          id?: string
          result?: Json | null
          success?: boolean
          tool_name?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_tool_calls_ai_request_id_fkey"
            columns: ["ai_request_id"]
            isOneToOne: false
            referencedRelation: "ai_requests"
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
      billing_products: {
        Row: {
          billing_period: Database["public"]["Enums"]["billing_period"]
          created_at: string
          id: string
          is_active: boolean
          plan_id: string
          provider: Database["public"]["Enums"]["billing_provider"]
          provider_product_id: string
          updated_at: string
        }
        Insert: {
          billing_period: Database["public"]["Enums"]["billing_period"]
          created_at?: string
          id?: string
          is_active?: boolean
          plan_id: string
          provider: Database["public"]["Enums"]["billing_provider"]
          provider_product_id: string
          updated_at?: string
        }
        Update: {
          billing_period?: Database["public"]["Enums"]["billing_period"]
          created_at?: string
          id?: string
          is_active?: boolean
          plan_id?: string
          provider?: Database["public"]["Enums"]["billing_provider"]
          provider_product_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "billing_products_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "plans"
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
      coach_availability: {
        Row: {
          coach_id: string
          created_at: string
          day_of_week: number
          end_time: string
          id: string
          is_active: boolean
          start_time: string
          timezone: string
          updated_at: string
        }
        Insert: {
          coach_id: string
          created_at?: string
          day_of_week: number
          end_time: string
          id?: string
          is_active?: boolean
          start_time: string
          timezone: string
          updated_at?: string
        }
        Update: {
          coach_id?: string
          created_at?: string
          day_of_week?: number
          end_time?: string
          id?: string
          is_active?: boolean
          start_time?: string
          timezone?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "coach_availability_coach_id_fkey"
            columns: ["coach_id"]
            isOneToOne: false
            referencedRelation: "coach_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      coach_client_permissions: {
        Row: {
          activity: boolean
          client_id: string
          coach_id: string
          created_at: string
          goals: boolean
          measurements: boolean
          mood: boolean
          nutrition: boolean
          progress_photos: boolean
          updated_at: string
          weight: boolean
        }
        Insert: {
          activity?: boolean
          client_id: string
          coach_id: string
          created_at?: string
          goals?: boolean
          measurements?: boolean
          mood?: boolean
          nutrition?: boolean
          progress_photos?: boolean
          updated_at?: string
          weight?: boolean
        }
        Update: {
          activity?: boolean
          client_id?: string
          coach_id?: string
          created_at?: string
          goals?: boolean
          measurements?: boolean
          mood?: boolean
          nutrition?: boolean
          progress_photos?: boolean
          updated_at?: string
          weight?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "coach_client_permissions_coach_id_client_id_fkey"
            columns: ["coach_id", "client_id"]
            isOneToOne: true
            referencedRelation: "coach_clients"
            referencedColumns: ["coach_id", "client_id"]
          },
        ]
      }
      coach_clients: {
        Row: {
          client_id: string
          coach_id: string
          created_at: string
          ended_at: string | null
          started_at: string
          status: Database["public"]["Enums"]["coach_client_status"]
          updated_at: string
        }
        Insert: {
          client_id: string
          coach_id: string
          created_at?: string
          ended_at?: string | null
          started_at?: string
          status?: Database["public"]["Enums"]["coach_client_status"]
          updated_at?: string
        }
        Update: {
          client_id?: string
          coach_id?: string
          created_at?: string
          ended_at?: string | null
          started_at?: string
          status?: Database["public"]["Enums"]["coach_client_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "coach_clients_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "coach_clients_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "coach_clients_coach_id_fkey"
            columns: ["coach_id"]
            isOneToOne: false
            referencedRelation: "coach_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      coach_payouts: {
        Row: {
          amount_cents: number
          coach_id: string
          created_at: string
          currency: string
          id: string
          idempotency_key_id: string | null
          period_end: string
          period_start: string
          status: Database["public"]["Enums"]["coach_payout_status"]
          stripe_payout_id: string | null
          updated_at: string
        }
        Insert: {
          amount_cents: number
          coach_id: string
          created_at?: string
          currency: string
          id?: string
          idempotency_key_id?: string | null
          period_end: string
          period_start: string
          status: Database["public"]["Enums"]["coach_payout_status"]
          stripe_payout_id?: string | null
          updated_at?: string
        }
        Update: {
          amount_cents?: number
          coach_id?: string
          created_at?: string
          currency?: string
          id?: string
          idempotency_key_id?: string | null
          period_end?: string
          period_start?: string
          status?: Database["public"]["Enums"]["coach_payout_status"]
          stripe_payout_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "coach_payouts_coach_id_fkey"
            columns: ["coach_id"]
            isOneToOne: false
            referencedRelation: "coach_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "coach_payouts_idempotency_key_id_fkey"
            columns: ["idempotency_key_id"]
            isOneToOne: false
            referencedRelation: "idempotency_keys"
            referencedColumns: ["id"]
          },
        ]
      }
      coach_platform_fees: {
        Row: {
          coach_id: string
          created_at: string
          effective_from: string
          id: string
          percentage: number
          updated_at: string
        }
        Insert: {
          coach_id: string
          created_at?: string
          effective_from: string
          id?: string
          percentage: number
          updated_at?: string
        }
        Update: {
          coach_id?: string
          created_at?: string
          effective_from?: string
          id?: string
          percentage?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "coach_platform_fees_coach_id_fkey"
            columns: ["coach_id"]
            isOneToOne: false
            referencedRelation: "coach_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      coach_profiles: {
        Row: {
          bio: string | null
          certifications: Json
          created_at: string
          currency: string
          headline: string | null
          hourly_rate: number | null
          id: string
          location: string | null
          online_only: boolean
          rating: number
          review_count: number
          specialties: string[]
          updated_at: string
          verification_status: Database["public"]["Enums"]["coach_verification_status"]
          years_experience: number | null
        }
        Insert: {
          bio?: string | null
          certifications?: Json
          created_at?: string
          currency?: string
          headline?: string | null
          hourly_rate?: number | null
          id: string
          location?: string | null
          online_only?: boolean
          rating?: number
          review_count?: number
          specialties?: string[]
          updated_at?: string
          verification_status?: Database["public"]["Enums"]["coach_verification_status"]
          years_experience?: number | null
        }
        Update: {
          bio?: string | null
          certifications?: Json
          created_at?: string
          currency?: string
          headline?: string | null
          hourly_rate?: number | null
          id?: string
          location?: string | null
          online_only?: boolean
          rating?: number
          review_count?: number
          specialties?: string[]
          updated_at?: string
          verification_status?: Database["public"]["Enums"]["coach_verification_status"]
          years_experience?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "coach_profiles_id_fkey"
            columns: ["id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "coach_profiles_id_fkey"
            columns: ["id"]
            isOneToOne: true
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      coach_reviews: {
        Row: {
          client_id: string
          coach_id: string
          created_at: string
          id: string
          rating: number
          review: string | null
          status: Database["public"]["Enums"]["coach_review_status"]
          updated_at: string
        }
        Insert: {
          client_id: string
          coach_id: string
          created_at?: string
          id?: string
          rating: number
          review?: string | null
          status?: Database["public"]["Enums"]["coach_review_status"]
          updated_at?: string
        }
        Update: {
          client_id?: string
          coach_id?: string
          created_at?: string
          id?: string
          rating?: number
          review?: string | null
          status?: Database["public"]["Enums"]["coach_review_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "coach_reviews_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "coach_reviews_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "coach_reviews_coach_id_fkey"
            columns: ["coach_id"]
            isOneToOne: false
            referencedRelation: "coach_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      coach_sessions: {
        Row: {
          agora_channel: string | null
          client_id: string | null
          coach_id: string
          created_at: string
          description: string | null
          duration_minutes: number
          id: string
          scheduled_at: string
          session_type: Database["public"]["Enums"]["coach_session_type"]
          status: Database["public"]["Enums"]["coach_session_status"]
          title: string
          updated_at: string
        }
        Insert: {
          agora_channel?: string | null
          client_id?: string | null
          coach_id: string
          created_at?: string
          description?: string | null
          duration_minutes: number
          id?: string
          scheduled_at: string
          session_type?: Database["public"]["Enums"]["coach_session_type"]
          status?: Database["public"]["Enums"]["coach_session_status"]
          title: string
          updated_at?: string
        }
        Update: {
          agora_channel?: string | null
          client_id?: string | null
          coach_id?: string
          created_at?: string
          description?: string | null
          duration_minutes?: number
          id?: string
          scheduled_at?: string
          session_type?: Database["public"]["Enums"]["coach_session_type"]
          status?: Database["public"]["Enums"]["coach_session_status"]
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "coach_sessions_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "coach_sessions_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "coach_sessions_coach_id_fkey"
            columns: ["coach_id"]
            isOneToOne: false
            referencedRelation: "coach_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      coach_specialties: {
        Row: {
          coach_id: string
          created_at: string
          id: string
          specialty: string
          updated_at: string
        }
        Insert: {
          coach_id: string
          created_at?: string
          id?: string
          specialty: string
          updated_at?: string
        }
        Update: {
          coach_id?: string
          created_at?: string
          id?: string
          specialty?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "coach_specialties_coach_id_fkey"
            columns: ["coach_id"]
            isOneToOne: false
            referencedRelation: "coach_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      coach_stripe_accounts: {
        Row: {
          charges_enabled: boolean
          coach_id: string
          created_at: string
          id: string
          onboarding_status: Database["public"]["Enums"]["stripe_onboarding_status"]
          payouts_enabled: boolean
          stripe_account_id: string
          updated_at: string
        }
        Insert: {
          charges_enabled?: boolean
          coach_id: string
          created_at?: string
          id?: string
          onboarding_status?: Database["public"]["Enums"]["stripe_onboarding_status"]
          payouts_enabled?: boolean
          stripe_account_id: string
          updated_at?: string
        }
        Update: {
          charges_enabled?: boolean
          coach_id?: string
          created_at?: string
          id?: string
          onboarding_status?: Database["public"]["Enums"]["stripe_onboarding_status"]
          payouts_enabled?: boolean
          stripe_account_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "coach_stripe_accounts_coach_id_fkey"
            columns: ["coach_id"]
            isOneToOne: true
            referencedRelation: "coach_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      coach_transactions: {
        Row: {
          amount_cents: number
          coach_id: string
          created_at: string
          currency: string
          id: string
          idempotency_key_id: string | null
          session_payment_intent_id: string | null
          stripe_ref: string | null
          type: Database["public"]["Enums"]["coach_transaction_type"]
          updated_at: string
        }
        Insert: {
          amount_cents: number
          coach_id: string
          created_at?: string
          currency: string
          id?: string
          idempotency_key_id?: string | null
          session_payment_intent_id?: string | null
          stripe_ref?: string | null
          type: Database["public"]["Enums"]["coach_transaction_type"]
          updated_at?: string
        }
        Update: {
          amount_cents?: number
          coach_id?: string
          created_at?: string
          currency?: string
          id?: string
          idempotency_key_id?: string | null
          session_payment_intent_id?: string | null
          stripe_ref?: string | null
          type?: Database["public"]["Enums"]["coach_transaction_type"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "coach_transactions_coach_id_fkey"
            columns: ["coach_id"]
            isOneToOne: false
            referencedRelation: "coach_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "coach_transactions_idempotency_key_id_fkey"
            columns: ["idempotency_key_id"]
            isOneToOne: false
            referencedRelation: "idempotency_keys"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "coach_transactions_session_payment_intent_id_fkey"
            columns: ["session_payment_intent_id"]
            isOneToOne: false
            referencedRelation: "session_payment_intents"
            referencedColumns: ["id"]
          },
        ]
      }
      comment_likes: {
        Row: {
          comment_id: string
          created_at: string
          updated_at: string
          user_id: string
        }
        Insert: {
          comment_id: string
          created_at?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          comment_id?: string
          created_at?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "comment_likes_comment_id_fkey"
            columns: ["comment_id"]
            isOneToOne: false
            referencedRelation: "comments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comment_likes_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comment_likes_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      comments: {
        Row: {
          author_id: string
          content: string
          created_at: string
          id: string
          parent_comment_id: string | null
          post_id: string
          status: Database["public"]["Enums"]["comment_status"]
          updated_at: string
        }
        Insert: {
          author_id: string
          content: string
          created_at?: string
          id?: string
          parent_comment_id?: string | null
          post_id: string
          status?: Database["public"]["Enums"]["comment_status"]
          updated_at?: string
        }
        Update: {
          author_id?: string
          content?: string
          created_at?: string
          id?: string
          parent_comment_id?: string | null
          post_id?: string
          status?: Database["public"]["Enums"]["comment_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "comments_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_parent_comment_id_fkey"
            columns: ["parent_comment_id"]
            isOneToOne: false
            referencedRelation: "comments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_parent_same_post_fk"
            columns: ["parent_comment_id", "post_id"]
            isOneToOne: false
            referencedRelation: "comments"
            referencedColumns: ["id", "post_id"]
          },
          {
            foreignKeyName: "comments_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "posts"
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
      conversation_members: {
        Row: {
          conversation_id: string
          joined_at: string
          last_read_message_id: string | null
          role: Database["public"]["Enums"]["conversation_member_role"]
          updated_at: string
          user_id: string
        }
        Insert: {
          conversation_id: string
          joined_at?: string
          last_read_message_id?: string | null
          role?: Database["public"]["Enums"]["conversation_member_role"]
          updated_at?: string
          user_id: string
        }
        Update: {
          conversation_id?: string
          joined_at?: string
          last_read_message_id?: string | null
          role?: Database["public"]["Enums"]["conversation_member_role"]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "conversation_members_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversation_members_last_read_message_fk"
            columns: ["last_read_message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversation_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversation_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      conversations: {
        Row: {
          created_at: string
          created_by: string
          group_id: string | null
          id: string
          type: Database["public"]["Enums"]["conversation_type"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by: string
          group_id?: string | null
          id?: string
          type: Database["public"]["Enums"]["conversation_type"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          group_id?: string | null
          id?: string
          type?: Database["public"]["Enums"]["conversation_type"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "conversations_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
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
      follows: {
        Row: {
          created_at: string
          followed_id: string
          follower_id: string
          id: string
          status: Database["public"]["Enums"]["follow_status"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          followed_id: string
          follower_id: string
          id?: string
          status?: Database["public"]["Enums"]["follow_status"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          followed_id?: string
          follower_id?: string
          id?: string
          status?: Database["public"]["Enums"]["follow_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "follows_followed_id_fkey"
            columns: ["followed_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "follows_followed_id_fkey"
            columns: ["followed_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "follows_follower_id_fkey"
            columns: ["follower_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "follows_follower_id_fkey"
            columns: ["follower_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
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
      group_invites: {
        Row: {
          accepted_at: string | null
          created_at: string
          expires_at: string
          group_id: string
          id: string
          invited_by: string
          invited_user_id: string | null
          token: string
          updated_at: string
        }
        Insert: {
          accepted_at?: string | null
          created_at?: string
          expires_at: string
          group_id: string
          id?: string
          invited_by: string
          invited_user_id?: string | null
          token: string
          updated_at?: string
        }
        Update: {
          accepted_at?: string | null
          created_at?: string
          expires_at?: string
          group_id?: string
          id?: string
          invited_by?: string
          invited_user_id?: string | null
          token?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_invites_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_invites_invited_by_fkey"
            columns: ["invited_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_invites_invited_by_fkey"
            columns: ["invited_by"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_invites_invited_user_id_fkey"
            columns: ["invited_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_invites_invited_user_id_fkey"
            columns: ["invited_user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      group_members: {
        Row: {
          group_id: string
          joined_at: string
          role: Database["public"]["Enums"]["group_role"]
          status: Database["public"]["Enums"]["group_member_status"]
          updated_at: string
          user_id: string
        }
        Insert: {
          group_id: string
          joined_at?: string
          role?: Database["public"]["Enums"]["group_role"]
          status?: Database["public"]["Enums"]["group_member_status"]
          updated_at?: string
          user_id: string
        }
        Update: {
          group_id?: string
          joined_at?: string
          role?: Database["public"]["Enums"]["group_role"]
          status?: Database["public"]["Enums"]["group_member_status"]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_members_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      group_rules: {
        Row: {
          created_at: string
          group_id: string
          id: string
          position: number
          rule_text: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          group_id: string
          id?: string
          position?: number
          rule_text: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          group_id?: string
          id?: string
          position?: number
          rule_text?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_rules_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
        ]
      }
      groups: {
        Row: {
          avatar_path: string | null
          cover_path: string | null
          created_at: string
          description: string | null
          goal_type: string | null
          id: string
          is_active: boolean
          member_limit: number | null
          name: string
          owner_id: string
          slug: string
          type: Database["public"]["Enums"]["group_type"]
          updated_at: string
          visibility: Database["public"]["Enums"]["group_visibility"]
        }
        Insert: {
          avatar_path?: string | null
          cover_path?: string | null
          created_at?: string
          description?: string | null
          goal_type?: string | null
          id?: string
          is_active?: boolean
          member_limit?: number | null
          name: string
          owner_id: string
          slug: string
          type?: Database["public"]["Enums"]["group_type"]
          updated_at?: string
          visibility?: Database["public"]["Enums"]["group_visibility"]
        }
        Update: {
          avatar_path?: string | null
          cover_path?: string | null
          created_at?: string
          description?: string | null
          goal_type?: string | null
          id?: string
          is_active?: boolean
          member_limit?: number | null
          name?: string
          owner_id?: string
          slug?: string
          type?: Database["public"]["Enums"]["group_type"]
          updated_at?: string
          visibility?: Database["public"]["Enums"]["group_visibility"]
        }
        Relationships: [
          {
            foreignKeyName: "groups_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "groups_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      iap_transactions: {
        Row: {
          apple_original_transaction_id: string
          apple_transaction_id: string
          created_at: string
          environment: Database["public"]["Enums"]["iap_environment"]
          expires_at: string | null
          id: string
          plan_id: string
          product_id: string
          purchased_at: string
          raw_payload: Json
          status: Database["public"]["Enums"]["iap_status"]
          updated_at: string
          user_id: string
        }
        Insert: {
          apple_original_transaction_id: string
          apple_transaction_id: string
          created_at?: string
          environment: Database["public"]["Enums"]["iap_environment"]
          expires_at?: string | null
          id?: string
          plan_id: string
          product_id: string
          purchased_at: string
          raw_payload: Json
          status: Database["public"]["Enums"]["iap_status"]
          updated_at?: string
          user_id: string
        }
        Update: {
          apple_original_transaction_id?: string
          apple_transaction_id?: string
          created_at?: string
          environment?: Database["public"]["Enums"]["iap_environment"]
          expires_at?: string | null
          id?: string
          plan_id?: string
          product_id?: string
          purchased_at?: string
          raw_payload?: Json
          status?: Database["public"]["Enums"]["iap_status"]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "iap_transactions_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "plans"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "iap_transactions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "iap_transactions_user_id_fkey"
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
      live_room_events: {
        Row: {
          created_at: string
          event_type: string
          id: string
          metadata: Json
          room_id: string
          updated_at: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          event_type: string
          id?: string
          metadata?: Json
          room_id: string
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          event_type?: string
          id?: string
          metadata?: Json
          room_id?: string
          updated_at?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "live_room_events_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "live_rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "live_room_events_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "live_room_events_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      live_room_hosts: {
        Row: {
          created_at: string
          role: Database["public"]["Enums"]["live_room_role"]
          room_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          role?: Database["public"]["Enums"]["live_room_role"]
          room_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          role?: Database["public"]["Enums"]["live_room_role"]
          room_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "live_room_hosts_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "live_rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "live_room_hosts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "live_room_hosts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      live_room_participants: {
        Row: {
          created_at: string
          hand_raised_at: string | null
          joined_at: string
          left_at: string | null
          role: Database["public"]["Enums"]["live_room_role"]
          room_id: string
          speak_state: Database["public"]["Enums"]["live_room_speak_state"]
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          hand_raised_at?: string | null
          joined_at?: string
          left_at?: string | null
          role?: Database["public"]["Enums"]["live_room_role"]
          room_id: string
          speak_state?: Database["public"]["Enums"]["live_room_speak_state"]
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          hand_raised_at?: string | null
          joined_at?: string
          left_at?: string | null
          role?: Database["public"]["Enums"]["live_room_role"]
          room_id?: string
          speak_state?: Database["public"]["Enums"]["live_room_speak_state"]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "live_room_participants_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "live_rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "live_room_participants_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "live_room_participants_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      live_rooms: {
        Row: {
          agora_channel: string
          coach_session_id: string | null
          created_at: string
          description: string | null
          ended_at: string | null
          group_id: string | null
          host_id: string
          id: string
          max_participants: number | null
          room_type: Database["public"]["Enums"]["live_room_type"]
          scheduled_at: string
          started_at: string | null
          status: Database["public"]["Enums"]["live_room_status"]
          title: string
          updated_at: string
        }
        Insert: {
          agora_channel: string
          coach_session_id?: string | null
          created_at?: string
          description?: string | null
          ended_at?: string | null
          group_id?: string | null
          host_id: string
          id?: string
          max_participants?: number | null
          room_type?: Database["public"]["Enums"]["live_room_type"]
          scheduled_at: string
          started_at?: string | null
          status?: Database["public"]["Enums"]["live_room_status"]
          title: string
          updated_at?: string
        }
        Update: {
          agora_channel?: string
          coach_session_id?: string | null
          created_at?: string
          description?: string | null
          ended_at?: string | null
          group_id?: string | null
          host_id?: string
          id?: string
          max_participants?: number | null
          room_type?: Database["public"]["Enums"]["live_room_type"]
          scheduled_at?: string
          started_at?: string | null
          status?: Database["public"]["Enums"]["live_room_status"]
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "live_rooms_coach_session_fk"
            columns: ["coach_session_id"]
            isOneToOne: false
            referencedRelation: "coach_sessions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "live_rooms_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "live_rooms_host_id_fkey"
            columns: ["host_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "live_rooms_host_id_fkey"
            columns: ["host_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
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
      message_attachments: {
        Row: {
          created_at: string
          id: string
          media_type: Database["public"]["Enums"]["media_type"]
          message_id: string
          size_bytes: number
          storage_path: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          media_type: Database["public"]["Enums"]["media_type"]
          message_id: string
          size_bytes: number
          storage_path: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          media_type?: Database["public"]["Enums"]["media_type"]
          message_id?: string
          size_bytes?: number
          storage_path?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "message_attachments_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
        ]
      }
      messages: {
        Row: {
          body: string | null
          conversation_id: string
          created_at: string
          deleted_at: string | null
          edited_at: string | null
          id: string
          message_type: Database["public"]["Enums"]["message_type"]
          metadata: Json
          reply_to_id: string | null
          sender_id: string
          updated_at: string
        }
        Insert: {
          body?: string | null
          conversation_id: string
          created_at?: string
          deleted_at?: string | null
          edited_at?: string | null
          id?: string
          message_type?: Database["public"]["Enums"]["message_type"]
          metadata?: Json
          reply_to_id?: string | null
          sender_id: string
          updated_at?: string
        }
        Update: {
          body?: string | null
          conversation_id?: string
          created_at?: string
          deleted_at?: string | null
          edited_at?: string | null
          id?: string
          message_type?: Database["public"]["Enums"]["message_type"]
          metadata?: Json
          reply_to_id?: string | null
          sender_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "messages_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_reply_to_id_fkey"
            columns: ["reply_to_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      moderation_actions: {
        Row: {
          action: string
          created_at: string
          id: string
          moderator_id: string
          reason: string | null
          target_id: string
          target_type: string
          updated_at: string
        }
        Insert: {
          action: string
          created_at?: string
          id?: string
          moderator_id: string
          reason?: string | null
          target_id: string
          target_type: string
          updated_at?: string
        }
        Update: {
          action?: string
          created_at?: string
          id?: string
          moderator_id?: string
          reason?: string | null
          target_id?: string
          target_type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "moderation_actions_moderator_id_fkey"
            columns: ["moderator_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "moderation_actions_moderator_id_fkey"
            columns: ["moderator_id"]
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
      notification_jobs: {
        Row: {
          attempts: number
          created_at: string
          dead_letter_at: string | null
          dead_letter_reason: string | null
          failed_at: string | null
          id: string
          idempotency_key_id: string | null
          last_error: string | null
          max_attempts: number
          next_attempt_at: string
          notification_id: string
          provider: Database["public"]["Enums"]["notification_provider"]
          scheduled_at: string
          sent_at: string | null
          status: Database["public"]["Enums"]["notification_job_status"]
          updated_at: string
          user_id: string
        }
        Insert: {
          attempts?: number
          created_at?: string
          dead_letter_at?: string | null
          dead_letter_reason?: string | null
          failed_at?: string | null
          id?: string
          idempotency_key_id?: string | null
          last_error?: string | null
          max_attempts?: number
          next_attempt_at?: string
          notification_id: string
          provider: Database["public"]["Enums"]["notification_provider"]
          scheduled_at?: string
          sent_at?: string | null
          status?: Database["public"]["Enums"]["notification_job_status"]
          updated_at?: string
          user_id: string
        }
        Update: {
          attempts?: number
          created_at?: string
          dead_letter_at?: string | null
          dead_letter_reason?: string | null
          failed_at?: string | null
          id?: string
          idempotency_key_id?: string | null
          last_error?: string | null
          max_attempts?: number
          next_attempt_at?: string
          notification_id?: string
          provider?: Database["public"]["Enums"]["notification_provider"]
          scheduled_at?: string
          sent_at?: string | null
          status?: Database["public"]["Enums"]["notification_job_status"]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_jobs_idempotency_key_id_fkey"
            columns: ["idempotency_key_id"]
            isOneToOne: false
            referencedRelation: "idempotency_keys"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_jobs_notification_id_fkey"
            columns: ["notification_id"]
            isOneToOne: false
            referencedRelation: "notifications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_jobs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_jobs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_preferences: {
        Row: {
          chat: boolean
          coaching: boolean
          created_at: string
          goals: boolean
          live: boolean
          marketing: boolean
          nutrition: boolean
          social: boolean
          updated_at: string
          user_id: string
        }
        Insert: {
          chat?: boolean
          coaching?: boolean
          created_at?: string
          goals?: boolean
          live?: boolean
          marketing?: boolean
          nutrition?: boolean
          social?: boolean
          updated_at?: string
          user_id: string
        }
        Update: {
          chat?: boolean
          coaching?: boolean
          created_at?: string
          goals?: boolean
          live?: boolean
          marketing?: boolean
          nutrition?: boolean
          social?: boolean
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_preferences_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_preferences_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          body: string
          created_at: string
          data: Json
          id: string
          read_at: string | null
          title: string
          type: string
          updated_at: string
          user_id: string
        }
        Insert: {
          body: string
          created_at?: string
          data?: Json
          id?: string
          read_at?: string | null
          title: string
          type: string
          updated_at?: string
          user_id: string
        }
        Update: {
          body?: string
          created_at?: string
          data?: Json
          id?: string
          read_at?: string | null
          title?: string
          type?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      plan_entitlements: {
        Row: {
          created_at: string
          id: string
          limit_period: string | null
          limit_value: number | null
          lookup_key: string
          plan_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          limit_period?: string | null
          limit_value?: number | null
          lookup_key: string
          plan_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          limit_period?: string | null
          limit_value?: number | null
          lookup_key?: string
          plan_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "plan_entitlements_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "plans"
            referencedColumns: ["id"]
          },
        ]
      }
      plans: {
        Row: {
          code: string
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          name: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      post_bookmarks: {
        Row: {
          created_at: string
          post_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          post_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          post_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "post_bookmarks_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "posts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "post_bookmarks_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "post_bookmarks_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      post_likes: {
        Row: {
          created_at: string
          post_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          post_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          post_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "post_likes_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "posts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "post_likes_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "post_likes_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      post_media: {
        Row: {
          created_at: string
          duration_seconds: number | null
          height: number | null
          id: string
          media_type: Database["public"]["Enums"]["media_type"]
          position: number
          post_id: string
          storage_path: string
          updated_at: string
          width: number | null
        }
        Insert: {
          created_at?: string
          duration_seconds?: number | null
          height?: number | null
          id?: string
          media_type: Database["public"]["Enums"]["media_type"]
          position?: number
          post_id: string
          storage_path: string
          updated_at?: string
          width?: number | null
        }
        Update: {
          created_at?: string
          duration_seconds?: number | null
          height?: number | null
          id?: string
          media_type?: Database["public"]["Enums"]["media_type"]
          position?: number
          post_id?: string
          storage_path?: string
          updated_at?: string
          width?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "post_media_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "posts"
            referencedColumns: ["id"]
          },
        ]
      }
      posts: {
        Row: {
          author_id: string
          content: string | null
          created_at: string
          group_id: string | null
          id: string
          post_type: Database["public"]["Enums"]["post_type"]
          status: Database["public"]["Enums"]["post_status"]
          updated_at: string
          visibility: Database["public"]["Enums"]["post_visibility"]
        }
        Insert: {
          author_id: string
          content?: string | null
          created_at?: string
          group_id?: string | null
          id?: string
          post_type?: Database["public"]["Enums"]["post_type"]
          status?: Database["public"]["Enums"]["post_status"]
          updated_at?: string
          visibility?: Database["public"]["Enums"]["post_visibility"]
        }
        Update: {
          author_id?: string
          content?: string | null
          created_at?: string
          group_id?: string | null
          id?: string
          post_type?: Database["public"]["Enums"]["post_type"]
          status?: Database["public"]["Enums"]["post_status"]
          updated_at?: string
          visibility?: Database["public"]["Enums"]["post_visibility"]
        }
        Relationships: [
          {
            foreignKeyName: "posts_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "posts_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "posts_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
        ]
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
      refunds: {
        Row: {
          amount_cents: number
          created_at: string
          id: string
          idempotency_key_id: string | null
          reason: string | null
          requested_by: string | null
          session_payment_intent_id: string
          status: Database["public"]["Enums"]["refund_status"]
          stripe_refund_id: string | null
          updated_at: string
        }
        Insert: {
          amount_cents: number
          created_at?: string
          id?: string
          idempotency_key_id?: string | null
          reason?: string | null
          requested_by?: string | null
          session_payment_intent_id: string
          status?: Database["public"]["Enums"]["refund_status"]
          stripe_refund_id?: string | null
          updated_at?: string
        }
        Update: {
          amount_cents?: number
          created_at?: string
          id?: string
          idempotency_key_id?: string | null
          reason?: string | null
          requested_by?: string | null
          session_payment_intent_id?: string
          status?: Database["public"]["Enums"]["refund_status"]
          stripe_refund_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "refunds_idempotency_key_id_fkey"
            columns: ["idempotency_key_id"]
            isOneToOne: false
            referencedRelation: "idempotency_keys"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_requested_by_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_requested_by_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_session_payment_intent_id_fkey"
            columns: ["session_payment_intent_id"]
            isOneToOne: false
            referencedRelation: "session_payment_intents"
            referencedColumns: ["id"]
          },
        ]
      }
      reports: {
        Row: {
          created_at: string
          description: string | null
          id: string
          reason: string
          reporter_id: string
          resolved_at: string | null
          status: Database["public"]["Enums"]["report_status"]
          target_id: string
          target_type: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          reason: string
          reporter_id: string
          resolved_at?: string | null
          status?: Database["public"]["Enums"]["report_status"]
          target_id: string
          target_type: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          reason?: string
          reporter_id?: string
          resolved_at?: string | null
          status?: Database["public"]["Enums"]["report_status"]
          target_id?: string
          target_type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "reports_reporter_id_fkey"
            columns: ["reporter_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_reporter_id_fkey"
            columns: ["reporter_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      room_banned_users: {
        Row: {
          banned_by: string
          created_at: string
          reason: string | null
          room_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          banned_by: string
          created_at?: string
          reason?: string | null
          room_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          banned_by?: string
          created_at?: string
          reason?: string | null
          room_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "room_banned_users_banned_by_fkey"
            columns: ["banned_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "room_banned_users_banned_by_fkey"
            columns: ["banned_by"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "room_banned_users_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "live_rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "room_banned_users_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "room_banned_users_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      room_moderation_events: {
        Row: {
          action: Database["public"]["Enums"]["room_moderation_action"]
          created_at: string
          id: string
          metadata: Json
          moderator_id: string
          room_id: string
          target_user_id: string
          updated_at: string
        }
        Insert: {
          action: Database["public"]["Enums"]["room_moderation_action"]
          created_at?: string
          id?: string
          metadata?: Json
          moderator_id: string
          room_id: string
          target_user_id: string
          updated_at?: string
        }
        Update: {
          action?: Database["public"]["Enums"]["room_moderation_action"]
          created_at?: string
          id?: string
          metadata?: Json
          moderator_id?: string
          room_id?: string
          target_user_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "room_moderation_events_moderator_id_fkey"
            columns: ["moderator_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "room_moderation_events_moderator_id_fkey"
            columns: ["moderator_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "room_moderation_events_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "live_rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "room_moderation_events_target_user_id_fkey"
            columns: ["target_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "room_moderation_events_target_user_id_fkey"
            columns: ["target_user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      session_bookings: {
        Row: {
          booked_at: string
          cancelled_at: string | null
          client_id: string
          created_at: string
          id: string
          payment_method: Database["public"]["Enums"]["booking_payment_method"]
          session_id: string
          status: Database["public"]["Enums"]["booking_status"]
          updated_at: string
        }
        Insert: {
          booked_at?: string
          cancelled_at?: string | null
          client_id: string
          created_at?: string
          id?: string
          payment_method?: Database["public"]["Enums"]["booking_payment_method"]
          session_id: string
          status?: Database["public"]["Enums"]["booking_status"]
          updated_at?: string
        }
        Update: {
          booked_at?: string
          cancelled_at?: string | null
          client_id?: string
          created_at?: string
          id?: string
          payment_method?: Database["public"]["Enums"]["booking_payment_method"]
          session_id?: string
          status?: Database["public"]["Enums"]["booking_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "session_bookings_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "session_bookings_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "session_bookings_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "coach_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      session_notes: {
        Row: {
          coach_id: string
          content: string
          created_at: string
          id: string
          session_id: string
          updated_at: string
          visibility: Database["public"]["Enums"]["session_note_visibility"]
        }
        Insert: {
          coach_id: string
          content: string
          created_at?: string
          id?: string
          session_id: string
          updated_at?: string
          visibility?: Database["public"]["Enums"]["session_note_visibility"]
        }
        Update: {
          coach_id?: string
          content?: string
          created_at?: string
          id?: string
          session_id?: string
          updated_at?: string
          visibility?: Database["public"]["Enums"]["session_note_visibility"]
        }
        Relationships: [
          {
            foreignKeyName: "session_notes_coach_id_fkey"
            columns: ["coach_id"]
            isOneToOne: false
            referencedRelation: "coach_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "session_notes_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "coach_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      session_payment_intents: {
        Row: {
          amount_cents: number
          client_id: string
          coach_id: string
          created_at: string
          currency: string
          id: string
          idempotency_key_id: string | null
          platform_fee_cents: number
          session_id: string
          status: Database["public"]["Enums"]["session_payment_status"]
          stripe_payment_intent_id: string
          updated_at: string
        }
        Insert: {
          amount_cents: number
          client_id: string
          coach_id: string
          created_at?: string
          currency: string
          id?: string
          idempotency_key_id?: string | null
          platform_fee_cents: number
          session_id: string
          status?: Database["public"]["Enums"]["session_payment_status"]
          stripe_payment_intent_id: string
          updated_at?: string
        }
        Update: {
          amount_cents?: number
          client_id?: string
          coach_id?: string
          created_at?: string
          currency?: string
          id?: string
          idempotency_key_id?: string | null
          platform_fee_cents?: number
          session_id?: string
          status?: Database["public"]["Enums"]["session_payment_status"]
          stripe_payment_intent_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "session_payment_intents_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "session_payment_intents_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "session_payment_intents_coach_id_fkey"
            columns: ["coach_id"]
            isOneToOne: false
            referencedRelation: "coach_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "session_payment_intents_idempotency_key_id_fkey"
            columns: ["idempotency_key_id"]
            isOneToOne: false
            referencedRelation: "idempotency_keys"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "session_payment_intents_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: true
            referencedRelation: "coach_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      subscription_events: {
        Row: {
          created_at: string
          event_type: string
          id: string
          payload: Json
          processed: boolean
          processed_at: string | null
          stripe_event_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          event_type: string
          id?: string
          payload: Json
          processed?: boolean
          processed_at?: string | null
          stripe_event_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          event_type?: string
          id?: string
          payload?: Json
          processed?: boolean
          processed_at?: string | null
          stripe_event_id?: string
          updated_at?: string
        }
        Relationships: []
      }
      subscriptions: {
        Row: {
          cancel_at_period_end: boolean
          created_at: string
          current_period_end: string
          current_period_start: string
          id: string
          plan_id: string
          status: Database["public"]["Enums"]["subscription_status"]
          stripe_customer_id: string | null
          stripe_subscription_id: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          cancel_at_period_end?: boolean
          created_at?: string
          current_period_end: string
          current_period_start: string
          id?: string
          plan_id: string
          status: Database["public"]["Enums"]["subscription_status"]
          stripe_customer_id?: string | null
          stripe_subscription_id?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          cancel_at_period_end?: boolean
          created_at?: string
          current_period_end?: string
          current_period_start?: string
          id?: string
          plan_id?: string
          status?: Database["public"]["Enums"]["subscription_status"]
          stripe_customer_id?: string | null
          stripe_subscription_id?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "subscriptions_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "plans"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_user_id_fkey"
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
      user_entitlements: {
        Row: {
          active: boolean
          created_at: string
          expires_at: string | null
          id: string
          limit_value: number | null
          lookup_key: string
          source: Database["public"]["Enums"]["entitlement_source"]
          updated_at: string
          user_id: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          expires_at?: string | null
          id?: string
          limit_value?: number | null
          lookup_key: string
          source: Database["public"]["Enums"]["entitlement_source"]
          updated_at?: string
          user_id: string
        }
        Update: {
          active?: boolean
          created_at?: string
          expires_at?: string | null
          id?: string
          limit_value?: number | null
          lookup_key?: string
          source?: Database["public"]["Enums"]["entitlement_source"]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_entitlements_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_entitlements_user_id_fkey"
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
      coach_can_access_client: {
        Args: { p_client_id: string; p_coach_id: string }
        Returns: boolean
      }
      increment_referral: { Args: { p_code: string }; Returns: undefined }
      is_conversation_member: {
        Args: { p_conversation_id: string }
        Returns: boolean
      }
      is_group_admin: { Args: { p_group_id: string }; Returns: boolean }
      is_group_member: { Args: { p_group_id: string }; Returns: boolean }
      is_platform_admin: { Args: never; Returns: boolean }
      is_room_banned: { Args: { p_room_id: string }; Returns: boolean }
      is_room_moderator: { Args: { p_room_id: string }; Returns: boolean }
      is_room_participant: { Args: { p_room_id: string }; Returns: boolean }
      owns_food_log: { Args: { p_food_log_id: string }; Returns: boolean }
      owns_post: { Args: { p_post_id: string }; Returns: boolean }
      waitlist_position: { Args: { p_email: string }; Returns: number }
    }
    Enums: {
      ai_message_role: "user" | "assistant" | "system" | "tool"
      ai_request_status: "pending" | "processing" | "completed" | "failed"
      billing_period: "weekly" | "monthly" | "annual"
      billing_provider: "apple" | "stripe"
      booking_payment_method: "stripe"
      booking_status:
        | "pending"
        | "payment_required"
        | "paid"
        | "confirmed"
        | "completed"
        | "cancelled"
        | "refunded"
      coach_client_status:
        | "pending"
        | "active"
        | "paused"
        | "ended"
        | "cancelled"
      coach_payout_status:
        | "pending"
        | "in_transit"
        | "paid"
        | "failed"
        | "cancelled"
      coach_review_status: "published" | "hidden" | "removed"
      coach_session_status:
        | "draft"
        | "available"
        | "booked"
        | "confirmed"
        | "completed"
        | "cancelled"
      coach_session_type: "video" | "audio" | "in_person"
      coach_transaction_type:
        | "charge"
        | "refund"
        | "payout"
        | "fee"
        | "adjustment"
      coach_verification_status:
        | "pending"
        | "verified"
        | "rejected"
        | "suspended"
      comment_status: "published" | "deleted" | "hidden"
      consent_type: "terms" | "privacy" | "health_data" | "marketing"
      conversation_member_role: "owner" | "admin" | "member"
      conversation_type: "direct" | "group" | "coach_client"
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
      entitlement_source: "apple" | "stripe" | "admin" | "promo"
      follow_status: "active" | "pending" | "blocked"
      food_log_source: "manual" | "barcode" | "photo" | "ai" | "import"
      goal_period: "daily" | "weekly" | "monthly" | "overall"
      goal_status: "active" | "paused" | "completed" | "cancelled"
      group_member_status: "active" | "pending" | "blocked" | "removed"
      group_role: "owner" | "admin" | "moderator" | "coach" | "member"
      group_type: "general" | "challenge" | "support" | "coaching"
      group_visibility: "public" | "private"
      iap_environment: "production" | "sandbox"
      iap_status: "active" | "expired" | "revoked" | "grace_period"
      idempotency_scope:
        | "payment"
        | "ai_write"
        | "booking"
        | "food_log"
        | "webhook"
        | "notification"
      idempotency_status: "pending" | "completed" | "failed"
      live_room_role: "host" | "moderator" | "speaker" | "listener"
      live_room_speak_state:
        | "listener"
        | "request_to_speak"
        | "approved_speaker"
        | "speaking"
      live_room_status: "scheduled" | "live" | "ended" | "cancelled"
      live_room_type: "public" | "group" | "coach_client"
      meal_type: "breakfast" | "lunch" | "dinner" | "snack" | "other"
      measurement_type:
        | "waist"
        | "chest"
        | "hips"
        | "thigh"
        | "arm"
        | "body_fat"
        | "muscle_mass"
      media_type: "image" | "video"
      message_type: "text" | "image" | "video" | "system"
      notification_job_status:
        | "queued"
        | "processing"
        | "sent"
        | "failed"
        | "dead_letter"
      notification_provider: "apns" | "email" | "web"
      post_status: "draft" | "published" | "archived" | "deleted"
      post_type: "text" | "photo" | "video" | "progress" | "nutrition" | "goal"
      post_visibility: "public" | "followers" | "private" | "group"
      privacy_visibility: "private" | "followers" | "public" | "coach"
      profile_activity_level:
        | "sedentary"
        | "light"
        | "moderate"
        | "active"
        | "very_active"
      refund_status: "pending" | "succeeded" | "failed" | "canceled"
      report_status: "pending" | "reviewing" | "resolved" | "dismissed"
      room_moderation_action:
        | "mute"
        | "remove"
        | "ban"
        | "approve_speaker"
        | "revoke_speaker"
        | "dismiss_hand"
      session_note_visibility: "coach_private" | "client_shared"
      session_payment_status:
        | "requires_payment"
        | "succeeded"
        | "refunded"
        | "failed"
      stripe_onboarding_status: "pending" | "complete" | "restricted"
      subscription_status:
        | "trialing"
        | "active"
        | "past_due"
        | "canceled"
        | "incomplete"
        | "incomplete_expired"
        | "unpaid"
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
      ai_message_role: ["user", "assistant", "system", "tool"],
      ai_request_status: ["pending", "processing", "completed", "failed"],
      billing_period: ["weekly", "monthly", "annual"],
      billing_provider: ["apple", "stripe"],
      booking_payment_method: ["stripe"],
      booking_status: [
        "pending",
        "payment_required",
        "paid",
        "confirmed",
        "completed",
        "cancelled",
        "refunded",
      ],
      coach_client_status: [
        "pending",
        "active",
        "paused",
        "ended",
        "cancelled",
      ],
      coach_payout_status: [
        "pending",
        "in_transit",
        "paid",
        "failed",
        "cancelled",
      ],
      coach_review_status: ["published", "hidden", "removed"],
      coach_session_status: [
        "draft",
        "available",
        "booked",
        "confirmed",
        "completed",
        "cancelled",
      ],
      coach_session_type: ["video", "audio", "in_person"],
      coach_transaction_type: [
        "charge",
        "refund",
        "payout",
        "fee",
        "adjustment",
      ],
      coach_verification_status: [
        "pending",
        "verified",
        "rejected",
        "suspended",
      ],
      comment_status: ["published", "deleted", "hidden"],
      consent_type: ["terms", "privacy", "health_data", "marketing"],
      conversation_member_role: ["owner", "admin", "member"],
      conversation_type: ["direct", "group", "coach_client"],
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
      entitlement_source: ["apple", "stripe", "admin", "promo"],
      follow_status: ["active", "pending", "blocked"],
      food_log_source: ["manual", "barcode", "photo", "ai", "import"],
      goal_period: ["daily", "weekly", "monthly", "overall"],
      goal_status: ["active", "paused", "completed", "cancelled"],
      group_member_status: ["active", "pending", "blocked", "removed"],
      group_role: ["owner", "admin", "moderator", "coach", "member"],
      group_type: ["general", "challenge", "support", "coaching"],
      group_visibility: ["public", "private"],
      iap_environment: ["production", "sandbox"],
      iap_status: ["active", "expired", "revoked", "grace_period"],
      idempotency_scope: [
        "payment",
        "ai_write",
        "booking",
        "food_log",
        "webhook",
        "notification",
      ],
      idempotency_status: ["pending", "completed", "failed"],
      live_room_role: ["host", "moderator", "speaker", "listener"],
      live_room_speak_state: [
        "listener",
        "request_to_speak",
        "approved_speaker",
        "speaking",
      ],
      live_room_status: ["scheduled", "live", "ended", "cancelled"],
      live_room_type: ["public", "group", "coach_client"],
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
      media_type: ["image", "video"],
      message_type: ["text", "image", "video", "system"],
      notification_job_status: [
        "queued",
        "processing",
        "sent",
        "failed",
        "dead_letter",
      ],
      notification_provider: ["apns", "email", "web"],
      post_status: ["draft", "published", "archived", "deleted"],
      post_type: ["text", "photo", "video", "progress", "nutrition", "goal"],
      post_visibility: ["public", "followers", "private", "group"],
      privacy_visibility: ["private", "followers", "public", "coach"],
      profile_activity_level: [
        "sedentary",
        "light",
        "moderate",
        "active",
        "very_active",
      ],
      refund_status: ["pending", "succeeded", "failed", "canceled"],
      report_status: ["pending", "reviewing", "resolved", "dismissed"],
      room_moderation_action: [
        "mute",
        "remove",
        "ban",
        "approve_speaker",
        "revoke_speaker",
        "dismiss_hand",
      ],
      session_note_visibility: ["coach_private", "client_shared"],
      session_payment_status: [
        "requires_payment",
        "succeeded",
        "refunded",
        "failed",
      ],
      stripe_onboarding_status: ["pending", "complete", "restricted"],
      subscription_status: [
        "trialing",
        "active",
        "past_due",
        "canceled",
        "incomplete",
        "incomplete_expired",
        "unpaid",
      ],
      units_system: ["metric", "imperial"],
    },
  },
} as const

