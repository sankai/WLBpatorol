# encording: UTF-8

class Worklog < ActiveRecord::Base

  belongs_to :dept, class_name: "Dept", foreign_key: :dept_code, primary_key: :code
  belongs_to :emp, class_name: "Emp", foreign_key: :emp_code, primary_key: :code
  belongs_to :holidaytype
  belongs_to :worktype
  validates_associated :dept, :emp

  @@overhrs_criterias = nil
  
  def self.create_criterias
    @@overhrs_criterias = Hash.new()
    @@overhrs_criterias[:red]    = 49.5 * 60
    @@overhrs_criterias[:yellow] = 25   * 60
  end  
  
  def self.get_overhrs_criteria(criteria_name)
    if @@overhrs_criterias.nil?
      self.create_criterias
    end
    return @@overhrs_criterias[criteria_name]
  end
  
  # 一日10時間（休憩を除く）以上作業していたらtrueを返す。
  def over_work_in_day?
    if self.work_minutes_in_day > 600
      return true
    end
    return false
  end
  
  # 一日の作業時間（休憩を除く）を分で返す。
  def work_minutes_in_day
    diff = self.wk_end - self.wk_start
    return (( diff / 60 )  - self.rest)
  end

  # 一日の超過時間（休憩を除く）を分で返す。7.75よりも少ない場合はマイナスになる
  # 仮実装（午前休、午後休などの場合の考慮はしていない）
  def overhrs_in_min
    unless self.wk_start == self.wk_end 
      return self.work_minutes_in_day - 465
    end
    return 0
  end
  
  # 年月を指定して、その月の労働日数を返す
  def self.number_of_workdays(year, month)
    count = 0
    last  = Date.new(year, month, -1)
    for i in 1..last.day do
      oneday = Date.new(year, month, i)
      unless Holiday.isOff?(oneday)
        count = count + 1
      end
    end
    
    puts "count is " + count.to_s
    
    return count
  end
  
  # 一か月の超過時間の基準を日単位にHashにして返す
  def self.criterias_for(year, month, criteria_name)
        
    criteria_per_day = self.get_overhrs_criteria(criteria_name) / self.number_of_workdays(year, month)
    sum = 0
    aHash = Hash.new()
    last  = Date.new(year, month, -1)

    for i in 1..last.day
      oneday = Date.new(year, month, i)
      unless Holiday.isOff?(oneday)
        sum = sum + criteria_per_day
      end
      aHash.store(i, sum)
    end
    return aHash
  end

  # マスタから名前を逆引きして、そのマスタデータのidを返す。
  # 見つからなかったらidとして1をセットする。
  def self.get_id_from_class(aClass, attr, value)
    o = aClass.where(attr => value)
    if o.empty?
      puts '***** not found ***** <' + value.to_s + '>'
      return 1
    end
    return o.first.id
  end
  
  # 作業日(属性workday)をmm/dd形式で返す。
  def workdayYM
    return self.workday.strftime("%m/%d")
  end
  
  # 作業日(属性workday)をmm/dd形式＋曜日で返す。
  def workdayYMwday
    @@wdays = ["日", "月", "火", "水", "木", "金", "土"]
    self.workdayYM + " (" + @@wdays[self.workday.wday] + ")"
  end
  
  # CSVを解析してworklogオブジェクトを作成して返す。
  def self.from_csv(anArray)
    w = new
    w.dept_code   = anArray[0]                                      # 所属コード
    w.emp_code    = anArray[1]                                      # 社員コード
    w.workday     = Date.strptime(anArray[2], "%Y/%m/%d")           # 日付
    w.holidaytype_id  = get_id_from_class(Holidaytype,  :name, anArray[3].to_s.encode('utf-8', 'sjis'))  # 休暇
    w.worktype_id = get_id_from_class(Worktype, :name, anArray[4].to_s.encode('utf-8', 'sjis'))  # 勤務
    w.rc_start    = Time.strptime(anArray[5],"%H:%M")               # 出勤
    w.wk_start    = Time.strptime(anArray[6],"%H:%M")               # 始業
    w.wk_end      = Time.strptime(anArray[7],"%H:%M")               # 終業
    w.rc_end      = Time.strptime(anArray[8],"%H:%M")               # 退勤
    w.rest        = anArray[9].to_i                                 # 休憩
    w.reason      = anArray[10].to_s.encode('utf-8', 'sjis')        # 乖離理由
    w.comment     = anArray[11].to_s.encode('utf-8', 'sjis')        # 備考
    w.check       = anArray[12].to_s.encode('utf-8', 'sjis')        # チェック
 
    return w   
  end
  
  # 作業日の日付部分だけをintegerとして返す。
  def day
    return self.workday.day
  end

  # 一か月分のworklogをDBから抽出し、Arrayにして返す。
  # DBに存在しない場合は、新規オブジェクトを作成してArrayにセットする
  def self.extractOneMonth(year, month, emp)
    first = Date.new(year, month, 1)
    last  = Date.new(year, month, -1)
    anArray = Array.new()
    fromDB  = Hash.new()
    self.where(workday: first..last, emp_code: emp.code).each do | worklog |
      fromDB.store(worklog.day, worklog)
    end
    for i in 1..last.day
      log = fromDB.fetch(i, nil)
      if log.nil?
        log = Worklog.new_on(year, month, i, emp)
        #log = Worklog.new(:workday => Date.new(year, month, i), :emp_id => emp.id, :dept_code => emp.dept.code)
        #log.set_defaultAttributes
        log.save
      end
      # 今日のレコードがあれば、現在時刻に応じて作業開始あるいは終了時間に現在時刻をセットする
      # ワンクリック登録を作ったので、いったん機能を停止
      # if log.current_day?
      # current_clock = Time.zone.now
      #  if current_clock.hour < 13
      #    log.wk_start = current_clock
      #  else
      #    log.wk_end   = current_clock
      #  end
      #end
      anArray.append(log)
    end
    return anArray
  end
  
  # 作業日が休日（土日or祝日）か否かを返す（労働日の場合はFalse）
  # 現状、土日は無条件に休日と見なし、その上でHolidaysマスタにエントリがあれば休日とみなしている
  def isOff?
    return Holiday.isOff?(self.workday)
  end
  
  # 休日であれば、そのことを示すＣＳＳのクラス名を返す
  def workday_css_class
    if self.isOff?
      return 'workday-off'.html_safe
    end
    return ''
  end
  
  # 新規オブジェクトを作成する際に、デフォルト値をセットする。
  def set_defaultAttributes
    year  = self.workday.year
    month = self.workday.month
    day   = self.workday.day
    
    @@workdayAttributes = {:rc_start=>Time.local(year,month,day, 00,00,00), :wk_start=>Time.local(year,month,day, 9,00,00), :rc_end=>Time.local(year,month,day, 00,00,00), :wk_end=>Time.local(year,month,day, 17,45,00), :rest=>60}
    
    @@holidayAttributes = {:rc_start=>Time.local(year,month,day, 00,00,00), :wk_start=>Time.local(year,month,day, 00,00,00), :rc_end=>Time.local(year,month,day, 00,00,00), :wk_end=>Time.local(year,month,day, 00,00,00), :rest=>0 }
    
    if isOff?
      self.attributes = @@holidayAttributes
      self.holidaytype_id = 2
      self.worktype_id    = 2
    else
      self.attributes = @@workdayAttributes
      self.holidaytype_id = 1
      self.worktype_id    = 1
    end
    
    return self

  end

  def current_day?
    return (self.workday == Date.current)
  end
  
  def today_mark
    if current_day?
      return '◆'
    end
    return ' '
  end
  
  def self.new_on(year, month, day, emp)
    newlog = self.new(:workday => Date.new(year, month, day), :emp_code => emp.code, :dept_code => emp.dept.code)
    newlog.set_defaultAttributes
    puts "new log is " + newlog.to_s + " ** " + newlog.emp_code
    return newlog
  end
  
  def wk_start_end_as_array
    if self.wk_start == self.wk_end
      return [ 12, 0, 0, 12, 0, 0 ]
    else
      return [ self.wk_start.hour, self.wk_start.min, self.wk_start.sec, self.wk_end.hour, self.wk_end.min, self.wk_end.sec ]
    end
  end
  
  
  
end