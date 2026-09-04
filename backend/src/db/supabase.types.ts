export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      audit_activity: {
        Row: {
          action: string
          actor: string
          category: string
          created_at: string
          details_json: Json
          id: string
        }
        Insert: {
          action: string
          actor: string
          category: string
          created_at?: string
          details_json: Json
          id: string
        }
        Update: {
          action?: string
          actor?: string
          category?: string
          created_at?: string
          details_json?: Json
          id?: string
        }
        Relationships: []
      }
      employees: {
        Row: {
          bmoni_user_id: string | null
          card_id: string | null
          country: string
          created_at: string
          email: string
          failed_stage: string | null
          first_name: string
          id: string
          last_name: string
          partner_id: string
          payroll_amount_minor: number
          payroll_currency: string | null
          phone_number: string | null
          status: string
          target_currency: string
          updated_at: string
          wallet_address: string | null
          wallet_id: string | null
        }
        Insert: {
          bmoni_user_id?: string | null
          card_id?: string | null
          country: string
          created_at?: string
          email: string
          failed_stage?: string | null
          first_name: string
          id: string
          last_name: string
          partner_id: string
          payroll_amount_minor?: number
          payroll_currency?: string | null
          phone_number?: string | null
          status?: string
          target_currency: string
          updated_at?: string
          wallet_address?: string | null
          wallet_id?: string | null
        }
        Update: {
          bmoni_user_id?: string | null
          card_id?: string | null
          country?: string
          created_at?: string
          email?: string
          failed_stage?: string | null
          first_name?: string
          id?: string
          last_name?: string
          partner_id?: string
          payroll_amount_minor?: number
          payroll_currency?: string | null
          phone_number?: string | null
          status?: string
          target_currency?: string
          updated_at?: string
          wallet_address?: string | null
          wallet_id?: string | null
        }
        Relationships: []
      }
      money_missions: {
        Row: {
          action_json: Json
          condition_json: Json
          created_at: string
          description: string
          id: string
          is_active: boolean
          rule_type: string
          title: string
          updated_at: string
        }
        Insert: {
          action_json: Json
          condition_json: Json
          created_at?: string
          description: string
          id: string
          is_active?: boolean
          rule_type: string
          title: string
          updated_at?: string
        }
        Update: {
          action_json?: Json
          condition_json?: Json
          created_at?: string
          description?: string
          id?: string
          is_active?: boolean
          rule_type?: string
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      payroll_items: {
        Row: {
          country: string
          created_at: string
          employee_id: string
          employee_name: string
          exchange_rate: number
          id: string
          payroll_run_id: string
          proposal_id: string | null
          status: string
          target_amount_minor: number
          target_currency: string
          usd_amount_minor: number
        }
        Insert: {
          country: string
          created_at?: string
          employee_id: string
          employee_name: string
          exchange_rate: number
          id: string
          payroll_run_id: string
          proposal_id?: string | null
          status?: string
          target_amount_minor: number
          target_currency: string
          usd_amount_minor: number
        }
        Update: {
          country?: string
          created_at?: string
          employee_id?: string
          employee_name?: string
          exchange_rate?: number
          id?: string
          payroll_run_id?: string
          proposal_id?: string | null
          status?: string
          target_amount_minor?: number
          target_currency?: string
          usd_amount_minor?: number
        }
        Relationships: [
          {
            foreignKeyName: "payroll_items_payroll_run_id_fkey"
            columns: ["payroll_run_id"]
            isOneToOne: false
            referencedRelation: "payroll_runs"
            referencedColumns: ["id"]
          },
        ]
      }
      payroll_runs: {
        Row: {
          created_at: string
          employee_count: number
          executed_at: string
          fee_usd_minor: number
          id: string
          reference: string | null
          status: string
          title: string
          total_usd_minor: number
        }
        Insert: {
          created_at?: string
          employee_count: number
          executed_at?: string
          fee_usd_minor?: number
          id: string
          reference?: string | null
          status?: string
          title: string
          total_usd_minor: number
        }
        Update: {
          created_at?: string
          employee_count?: number
          executed_at?: string
          fee_usd_minor?: number
          id?: string
          reference?: string | null
          status?: string
          title?: string
          total_usd_minor?: number
        }
        Relationships: []
      }
      webhook_events: {
        Row: {
          bmoni_event_id: string | null
          event_type: string
          id: string
          payload_json: Json
          processed_at: string
        }
        Insert: {
          bmoni_event_id?: string | null
          event_type: string
          id: string
          payload_json: Json
          processed_at?: string
        }
        Update: {
          bmoni_event_id?: string | null
          event_type?: string
          id?: string
          payload_json?: Json
          processed_at?: string
        }
        Relationships: []
      }
      webhook_subscriptions: {
        Row: {
          active: boolean
          callback_url: string
          created_at: string
          events: Json
          id: string
          partner_id: string
          secret_key: string | null
          updated_at: string
        }
        Insert: {
          active?: boolean
          callback_url: string
          created_at?: string
          events?: Json
          id: string
          partner_id: string
          secret_key?: string | null
          updated_at?: string
        }
        Update: {
          active?: boolean
          callback_url?: string
          created_at?: string
          events?: Json
          id?: string
          partner_id?: string
          secret_key?: string | null
          updated_at?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
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

export const Constants = {
  public: {
    Enums: {},
  },
} as const
