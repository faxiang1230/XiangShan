#coding:utf-8

import smtplib
from email.mime.text import MIMEText
from email.header import Header

import argparse

parser = argparse.ArgumentParser(description='mail sending')
parser.add_argument("--sender", type=str, default="username@email.com", help="sender mail")
parser.add_argument("--receiver", type=str, default="username@email.com", help="receiver mail")
parser.add_argument("--subject", type=str, default="email test", help="subject")
parser.add_argument("--text", type=str, default="hello python", help="email body")
parser.add_argument("--smtpserver", type=str, default="smtp.163.com", help="smtp server")
parser.add_argument("--passwd", type=str, default="XXXXXX", help="authorization password")

args = parser.parse_args()

msg = MIMEText (args.text, 'plain', 'utf-8')
msg['Subject'] = Header(args.subject, 'utf-8')

print(args.sender, 'send email to', args.receiver)
print('subject :', args.subject)
print('body    :', args.text)

smtp = smtplib.SMTP()
smtp.connect( args.smtpserver )
smtp.login( args.sender, args.passwd )
smtp.sendmail( args.sender, args.receiver, msg.as_string() )
smtp.quit()

