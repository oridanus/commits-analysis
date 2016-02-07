require 'rubygems'
require 'jira'
require 'fileutils'
require 'csv'
require 'builder'

@username = "jira_user"
@password = "jira_pass^"
@jira_url = 'https://jira.yourorg.com:443'

@source_of_commits_param = ARGV[0]
@value_of_commits_param = ARGV[1]
@output_file_param = ARGV[2]

@git_log_flags = '--no-merges --pretty=format:%an,%ai,%s,%h'

@jira_client = JIRA::Client.new({
    username: @username,
    password: @password,
    site: @jira_url,
    context_path: '',
    auth_type: :basic,
    ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE,
    user_ssl: true
})

def issues_by_jql(jql)
  query_options = {
      :fields => [],
      :start_at => 0,
      :max_results => 100000
  }
  @jira_client.Issue.jql(jql, query_options)
end

def jira_issue_keys(issues)
  issues.map { |issue| issue.key }
end

def issue_keys_with_grep(issue_keys)
  ' --grep ' + issue_keys.join(' --grep ')
end

def special_grep(special_grep_file)
  " --grep \"" + File.read(special_grep_file).split(/\n/).join("\" --grep \"") + "\""
end

def jira_key_from_commit(commit)
  commit[:full_comment].split(' ').first.split(':').first
end

def date_from_commit(commit)
  commit[:date_and_time].split(' ').first
end

def commits_from_csv(commits_csv)
  CSV.parse("Auther,Date and Time,Full Comment\n" + commits_csv, :headers => true, :header_converters => :symbol).collect do |row|
    Hash[row.collect { |c, r| [c, r] }]
  end
end

def date_to_jira_issues_to_commits(commits)
  date_to_jira_issues_to_commits = Hash.new { |hash, key| hash[key] = Hash.new { |hash, key| hash[key] = Array.new } }
  commits.each do |commit|
    date_to_jira_issues_to_commits[Date.parse(date_from_commit(commit))][jira_key_from_commit(commit)].push commit
  end
  date_to_jira_issues_to_commits
end

def key_to_summary(jira_key)
  @jira_client.Issue.find(jira_key).fields['summary']
end

def key_to_estimation(jira_key)
  original_estimate = @jira_client.Issue.find(jira_key).fields['timeoriginalestimate']
  original_estimate ? original_estimate/28800 : nil
end

def table_from(builder, date_to_jira_issues_to_commits)

  all_dates = date_to_jira_issues_to_commits.sort.map  { |k, _| k}
  all_jira_issues = Set.new
  date_to_jira_issues_to_commits.values.each do |jira_issues_to_commits|
    all_jira_issues.merge jira_issues_to_commits.keys
  end

    builder.tr {
      ([''] + all_dates + ['Actual Total Days Worked On', 'Days Estimated']).each { |date|
        builder.th(date)}
    }
    all_jira_issues.each { |issue|
      builder.tr {
        builder.th("#{issue} - #{key_to_summary(issue)}")
        days = 0
        all_dates.each  { |date|
            commits = date_to_jira_issues_to_commits[date][issue]
            days += 1 unless commits.empty?
            builder.td(commits.empty? ? '' : commits.size)
          }
        estimation = key_to_estimation(issue)

        clazz = if estimation
                  if days > estimation
                    'exceeded_estimation'
                  else
                    'as_estimated'
                  end
                else
                  'no_estimation'
                end

        builder.td(days, 'class' => clazz)
        builder.td(estimation != nil ? estimation : '', 'class' => clazz)
        }
      }
end

def html_with_table(date_to_jira_issues_to_commits)
  html_builder = Builder::XmlMarkup.new(:indent => 2)
  html_builder.html {
    html_builder.head {
      html_builder.title("Commit Analysis")
      html_builder.script(' ', 'src' => 'http://ajax.googleapis.com/ajax/libs/jquery/1.6.2/jquery.min.js')
      html_builder.script(' ', 'src' => 'jquery.hottie.js')
      html_builder.style('th {clear: both; margin-top: 5px; list-style: none; height: 10px; background-color:#a2e6ff;}
                          tr td { float: left; display: block;  line-height: 20px; text-align:center;}
                          .exceeded_estimation { background-color:#f63e00;}
                          .as_estimated { background-color:#36ff36;}
                          .no_estimation { background-color:#676767; }')
    }
    html_builder.body {
      html_builder.table('id' => 'commits-table') { table_from(html_builder, date_to_jira_issues_to_commits) }
      html_builder.script('$(function(){
                             $("#commits-table td:not(.exceeded_estimation):not(.as_estimated):not(.no_estimation)").hottie({
                              colorArray : [
                                "#d8ffd8",
                                "#00f600",
                                "#005400",
                              ],
                             readValue : function(e) {
                                return $(e).text() == "" ? 0 : $(e).text()
                              }
                            })
                        }
                        );
                        ')
    }
  }
end


commits_csv =
    case @source_of_commits_param.downcase
        when 'jql'
            `git log #{issue_keys_with_grep(jira_issue_keys(issues_by_jql(@value_of_commits_param)))} #{@git_log_flags}`
        when 'csv_file'
            File.read(@value_of_commits_param)
        else
            raise "unsupported source - [#{@source_of_commits_param}]"
    end

commits = commits_from_csv(commits_csv)

date_to_jira_issues_to_commits = date_to_jira_issues_to_commits(commits)

File.write(@output_file_param, html_with_table(date_to_jira_issues_to_commits))


