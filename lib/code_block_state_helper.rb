module CodeBlockStateHelper
  private

  def reset_code_block_state
    @state = :outside_code_block
    @current_code_content = ""
    @current_block_lang = ""


    @current_block_rerun = false
    @current_block_run = true
    @current_block_explain = false
    @current_block_result = true
  end
end
