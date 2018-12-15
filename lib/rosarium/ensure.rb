require 'rosarium'

class Rosarium::Promise

  def ensure(&block)
    self.then(Proc.new do |e|
      block.call self ; raise e
    end) do |v|
      block.call self ; v
    end
  end

end
