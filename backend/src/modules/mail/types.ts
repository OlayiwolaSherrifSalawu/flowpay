export interface EmailAddress {
  name?: string;
  address: string;
}

export interface Attachment {
  filename: string;
  content?: string | Buffer;
  path?: string;
  contentType?: string;
  cid?: string;
}

export interface SendMailOptions {
  to: string | string[] | EmailAddress | EmailAddress[];
  subject: string;
  html: string;
  text?: string;
  from?: string | EmailAddress;
  replyTo?: string;
  cc?: string | string[];
  bcc?: string | string[];
  attachments?: Attachment[];
}

export interface SendMailResult {
  success: boolean;
  messageId?: string;
  accepted?: string[];
  rejected?: string[];
  error?: string;
}

export interface SmtpConnectionStatus {
  connected: boolean;
  host: string;
  port: number;
  secure: boolean;
  user: string;
  timestamp: string;
  error?: string;
}

// Template parameter payloads
export interface OtpEmailParams {
  to: string;
  recipientName?: string;
  code: string;
  expiryMinutes?: number;
  actionDescription?: string;
}

export interface WelcomeEmailParams {
  to: string;
  recipientName: string;
  accountType?: 'personal' | 'business' | 'both';
  dashboardUrl?: string;
}

export interface EmployeeInviteParams {
  to: string;
  recipientName: string;
  employerName?: string;
  companyName?: string;
  inviteUrl: string;
  country: string;
  payrollAmount?: number | string;
  currency?: string;
  targetCurrency?: string;
}

export interface PayrollReceiptParams {
  to: string;
  recipientName: string;
  employeeName?: string;
  amount: number | string;
  currency: string;
  txHash?: string;
  date?: string;
  status?: string;
  companyName?: string;
}

export interface TransferReceiptParams {
  to: string;
  recipientName: string;
  senderName?: string;
  recipientEmail?: string;
  amount: number | string;
  currency: string;
  txHash?: string;
  date?: string;
  type?: 'SENT' | 'RECEIVED';
}

export interface SecurityAlertParams {
  to: string;
  recipientName: string;
  action: string;
  timestamp?: string;
  ipAddress?: string;
  device?: string;
  location?: string;
}
