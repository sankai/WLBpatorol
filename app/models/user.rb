class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  
  # 社員コードは必須
  validates :code, presence: true
  
  # 従業員クラスから同じ社員コードのデータを見つけて返す。
  def emp
    Emp.where(:code => self.code).first
  end
  
  def dept_range
    return self.emp.dept.code_range
  end
end
