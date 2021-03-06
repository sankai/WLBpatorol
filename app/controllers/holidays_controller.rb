class HolidaysController < ApplicationController
  before_action :set_holiday, only: [:show, :edit, :update, :destroy]

  respond_to :html

  def index
    @holidays = Holiday.all
    respond_with(@holidays)
  end

  def show
    respond_with(@holiday)
  end

  def new
    @holiday = Holiday.new
    respond_with(@holiday)
  end

  def edit
  end

  def create
    @holiday = Holiday.new(holiday_params)
    @holiday.save
    respond_with(@holiday)
  end

  def update
    @holiday.update(holiday_params)
    respond_with(@holiday)
  end

  def destroy
    @holiday.destroy
    respond_with(@holiday)
  end

  private
    def set_holiday
      @holiday = Holiday.find(params[:id])
    end

    def holiday_params
      params.require(:holiday).permit(:holidaydate, :year, :comment)
    end
end
