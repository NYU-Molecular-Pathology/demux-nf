Channel.fromPath("${params.output_dir}/email/attachments/*").set { email_attachments_channel }

String subject_line = new File("${params.output_dir}/email/subject.txt").text
def body = new File("${params.output_dir}/email/body.txt").text
def attachments = email_attachments_channel.toList().getVal()

sendMail {
  from "${params.email_to}"
  to "${params.email_from}"
  // attach attachments // remove attachments because its constantly breaking on phoenix HPC system
  subject subject_line
  """
  ${body}
  """.stripIndent()
}
