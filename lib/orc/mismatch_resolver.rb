require 'orc/actions'

class Orc::MismatchResolver
  def in_case(state, name)
    [
      :should_participate,
      :does_participate,
      :version_mismatch,
      :is_healthy,
      :is_drained,
    ].each { |k|
      if state[k].nil?
        t_state = state.clone
        f_state = state.clone
        t_state[k] = true
        f_state[k] = false
        in_case(t_state, name)
        in_case(f_state, name)
        return
      end
    }
    @cases[state] = lambda {|instance| Orc::Action.const_get(name).new(@remote_client,instance)}
  end

  def initialize(remote_client)
    @remote_client = remote_client
    @cases = {}
    in_case({
      :should_participate => true,
      :does_participate   => true,
      :version_mismatch   => false,
      :is_healthy         => true,
    }, 'ResolvedCompleteAction')
    in_case({
      :should_participate => true,
      :does_participate   => true,
      :version_mismatch   => false,
      :is_healthy         => false,
    }, 'WaitForHealthyAction')
    in_case({
      :should_participate => false,
      :does_participate   => false,
      :version_mismatch   => false,
    }, 'ResolvedCompleteAction')
    in_case({
      :should_participate => true,
      :does_participate   => true,
      :version_mismatch   => true,
    }, 'DisableParticipationAction')
    in_case({
      :does_participate   => false,
      :version_mismatch   => true,
      :is_drained         => true,
    }, 'UpdateVersionAction')
    in_case({
      :does_participate   => false,
      :version_mismatch   => true,
      :is_drained         => false,
    }, 'WaitForDrainedAction')
    in_case({
      :should_participate => true,
      :does_participate   => false,
      :version_mismatch   => false,
      :is_healthy         => true,
    }, 'EnableParticipationAction')
    in_case({
       :should_participate => true,
       :does_participate   => false,
       :version_mismatch   => false,
       :is_healthy         => false,
     }, 'WaitForHealthyAction')
    in_case({
      :should_participate => false,
      :does_participate   => true,
    }, 'DisableParticipationAction')
    in_case({
      :should_participate => false,
      :does_participate   => true,
    }, 'DisableParticipationAction')
  end

  def get_case(state)
    return @cases[state] || raise("CASE NOT HANDLED #{state}")
  end

  def resolve(instance)
    return get_case(
      :should_participate => instance.group.target_participation,
      :does_participate   => instance.participation,
      :version_mismatch   => instance.version_mismatch?,
      :is_healthy         => instance.healthy?,
      :is_drained         => instance.stoppable? # FIXME - should come from model of LB connections instead?
    ).call(instance)
  end
end

