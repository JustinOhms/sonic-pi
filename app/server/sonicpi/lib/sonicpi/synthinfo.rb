module SonicPi

  class BaseInfo
    attr_accessor :should_validate
    attr_reader :scsynth_name, :info

    def initialize
      @scsynth_name = "#{prefix}#{synth_name}"
      @should_validate = true
      @info = default_arg_info.merge(specific_arg_info)
    end

    def rrand(min, max)
      range = (min - max).abs
      r = rand(range.to_f)
      smallest = [min, max].min
      r + smallest
    end

    def doc
       "Please write documentation!"
    end

    def arg_defaults
      raise "please implement me!"
    end

    def name
      raise "please implement me!"
    end

    def prefix
      ""
    end

    def synth_name
      raise "Please implement me for #{self.class}!"
    end

    def args
      args_defaults.keys
    end

    def arg_doc(arg_name)
      info = arg_info[arg_name.to_sym]
      info[:doc] if info
    end

    def arg_default(arg_name)
      arg_defaults[arg_name.to_sym]
    end

    def validate!(*args)
      return true unless @should_validate
      args_h = resolve_synth_opts_hash_or_array(args)

      args_h.each do |k, v|
        k_sym = k.to_sym
#        raise "Value of argument #{k_sym.inspect} must be a number, got #{v.inspect}." unless v.is_a? Numeric

        arg_validations(k_sym).each do |v_fn, msg|
          raise "Value of argument #{k_sym.inspect} #{msg}, got #{v.inspect}." unless v_fn.call(args_h)
        end
      end
    end

    def arg_validations(arg_name)
      arg_information = @info[arg_name] || {}
      arg_information[:validations] || []
    end

    def bpm_scale_args
      return @cached_bpm_scale_args if @cached_bpm_scale_args

      args_to_scale = []
      @info.each do |k, v|
        args_to_scale << k if v[:bpm_scale]
      end

      @cached_bpm_scale_args = args_to_scale
    end

    def arg_info
      #Specifically for doc usage. Consider changing name do doc_info
      #Don't call as part of audio loops as slow. Use .info directly
      res = {}
      arg_defaults.each do |arg, default|
        default_info = @info[arg] || {}
        constraints = (default_info[:validations] || []).map{|el| el[1]}
        new_info = {}
        new_info[:doc] = default_info[:doc]
        new_info[:default] = default
        new_info[:constraints] = constraints
        new_info[:modulatable] = default_info[:modulatable]
        res[arg] = new_info
      end

      res

    end

    def kill_delay(args_h)
      1
    end

    private

    def generic_slide_doc(k)
      return "Amount of time (in seconds) for the #{k} value to change. A long #{k}_slide value means that the #{k} takes a long time to slide from the previous value to the new value. A #{k}_slide of 0 means that the #{k} instantly changes to the new value."
    end

    def v_positive(arg)
      [lambda{|args| args[arg] >= 0}, "must be zero or greater"]
    end

    def v_positive_not_zero(arg)
      [lambda{|args| args[arg] > 0}, "must be greater than zero"]
    end

    def v_between_inclusive(arg, min, max)
      [lambda{|args| args[arg] >= min && args[arg] <= max}, "must be a value between #{min} and #{max} inclusively"]
    end

    def v_between_exclusive(arg, min, max)
      [lambda{|args| args[arg] > min && args[arg] < max}, "must be a value between #{min} and #{max} exclusively"]
    end

    def v_less_than(arg,  max)
      [lambda{|args| args[arg] < max}, "must be a value less than #{max}"]
    end

    def v_one_of(arg, valid_options)
      [lambda{|args| valid_options.include?(args[arg])}, "must be one of the following values: #{valid_options.inspect}"]
    end

    def default_arg_info
      {
        :mix =>
        {
          :doc => "The amount (percentage) of FX present in the resulting sound represented as a value between 0 and 1. For example, a mix of 0 means that only the original sound is heard, a mix of 1 means that only the FX is heard (typically the default) and a mix of 0.5 means that half the original and half of the FX is heard. ",
          :validations => [v_between_inclusive(:mix, 0, 1)],
          :modulatable => true
        },

        :mix_slide =>
        {
          :doc => "Amount of time (in seconds) for the mix value to change. A long slide value means that the mix takes a long time to slide from the previous value to the new value. A slide of 0 means that the mix instantly changes to the new value.",
          :validations => [v_between_inclusive(:mix_slide, 0, 1)],
          :modulatable => true
        },

        :note =>
        {
          :doc => "Note to play. Either a MIDI number or a symbol representing a note. For example: 30, 52, :C, :C2, :Eb4, or :Ds3",
          :validations => [v_positive(:note)],
          :modulatable => true
        },

        :note_slide =>
        {
          :doc => "Amount of time (in seconds) for the note to change. A long slide value means that the note takes a long time to slide from the previous note to the new note. A slide of 0 means that the note instantly changes to the new note.",
          :validations => [v_positive(:note_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :amp =>
        {
          :doc => "The amplitude of the sound. Typically a value between 0 and 1. Higher amplitudes may be used, but won't make the sound louder, it will just reduce the quality of all the sounds currently being played (due to compression.)",
          :validations => [v_positive(:amp)],
          :modulatable => true
        },

        :amp_slide =>
        {
          :doc => "Amount of time (in seconds) for the amplitude (amp) to change. A long slide value means that the amp takes a long time to slide from the previous amplitude to the new amplitude. A slide of 0 means that the amplitude instantly changes to the new amplitude.",
          :validations => [v_positive(:amp_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :pan =>
        {

          :doc => "Position of sound in stereo. With headphones on, this means how much of the sound is in the left ear, and how much is in the right ear. With a value of -1, the soundis completely in the left ear, a value of 0 puts the sound equally in both ears and a value of 1 puts the sound in the right ear. Values in between -1 and 1 move the sound accordingly.",
          :validations => [v_between_inclusive(:pan, -1, 1)],
          :modulatable => true
        },

        :pan_slide =>
        {
          :doc => "Amount of time (in seconds) for the pan to change. A long slide value means that the pan takes a long time to slide from the previous pan position to the new pan position. A slide of 0 means that the pan instantly changes to the new pan position.",
          :validations => [v_positive(:pan_slide)],
          :modulatable => true,
          :bpm_scale => true
        },


        :attack =>
        {
          :doc => "Amount of time (in seconds) for sound to reach full amplitude (attack_leve). A short attack (i.e. 0.01) makes the initial part of the sound very percussive like a sharp tap. A longer attack (i.e 1) fades the sound in gently. Full length of sound is attack + sustain + release.",
          :validations => [v_positive(:attack)],
          :modulatable => false,
          :bpm_scale => true
        },

        :decay =>
        {
          :doc => "Amount of time (in seconds) for the sound to move from full amplitude (attack_level) to the sustain amplitude (sustain_level).",
          :validations => [v_positive(:decay)],
          :modulatable => false,
          :bpm_scale => true
        },

        :sustain =>
        {
          :doc => "Amount of time (in seconds) for sound to remain at full amplitude. Longer sustain values result in longer sounds. Full length of sound is attack + sustain + release.",
          :validations => [v_positive(:sustain)],
          :modulatable => false,
          :bpm_scale => true
        },

        :release =>
        {
          :doc => "Amount of time (in seconds) for sound to move from full amplitude to silent. A short release (i.e. 0.01) makes the final part of the sound very percussive (potentially resulting in a click). A longer release (i.e 1) fades the sound out gently. Full length of sound is attack + sustain + release.",
          :validations => [v_positive(:release)],
          :modulatable => false,
          :bpm_scale => true
        },

        :attack_level =>
        {
          :doc => "Amplitude level reached after attack phase and immediately before decay phase",
          :validations => [v_positive(:attack_level)],
          :modulatable => false
        },

        :sustain_level =>
        {
          :doc => "Amplitude level reached after decay phase and immediately before release phase.",
          :validations => [v_positive(:sustain_level)],
          :modulatable => false
        },

        :cutoff =>
        {
          :doc => "MIDI note representing the highest frequencies allowed to be present in the sound. A low value like 30 makes the sound round and dull, a high value like 100 makes the sound buzzy and crispy.",
          :validations => [v_positive(:cutoff), v_less_than(:cutoff, 130)],
          :modulatable => true
        },

        :cutoff_slide =>
        {
          :doc => "Amount of time (in seconds) for the cutoff value to change. A long cutoff_slide value means that the cutoff takes a long time to slide from the previous value to the new value. A cutoff_slide of 0 means that the cutoff instantly changes to the new value.",
          :validations => [v_positive(:cutoff_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :detune =>
        {
          :doc => "Distance (in MIDI notes) between components of sound. Affects thickness, sense of tuning and harmony. Tiny values such as 0.1 create a thick sound. Larger values such as 0.5 make the tuning sound strange. Even bigger values such as 5 create chord-like sounds.",
          :validations => [],
          :modulatable => true
        },

        :detune_slide =>
        {
          :doc => generic_slide_doc(:detune),
          :validations => [v_positive(:detune_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :mod_phase =>
        {
          :doc => "Phase duration in seconds of oscillations between the two notes. Time it takes to switch betwen the notes.",
          :validations => [v_positive_not_zero(:mod_phase)],
          :modulatable => true,
          :bpm_scale => true
        },

        :mod_phase_offset =>
        {
          :doc => "Intial modulation phase offset (a value between 0 and 1).",
          :validations => [v_between_inclusive(:mod_phase_offset, 0, 1)],
          :modulatable => false
        },

        :mod_phase_slide =>
        {
          :doc => generic_slide_doc(:mod_phase),
          :validations => [v_positive(:mod_phase_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :mod_range =>
        {
          :doc => "The size of gap between modulation notes. A gap of 12 is one octave.",
          :validations => [v_positive(:mod_range)],
          :modulatable => true
        },

        :mod_range_slide =>
        {
          :doc => generic_slide_doc(:mod_range),
          :validations => [v_positive(:mod_range_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :mod_width =>
        {
          :doc => "The phase width of the modulation. Represents how even the gap between modulations is.",
          :validations => [v_between_exclusive(:mod_width, 0, 1)],
          :modulatable => true
        },

        :mod_width_slide =>
        {
          :doc => generic_slide_doc(:mod_width),
          :validations => [v_positive(:mod_width_slide)],
          :modulatable => true,
          :bpm_scale => true
        }

      }
    end

    def specific_arg_info
      {}
    end

  end

  class SynthInfo < BaseInfo

  end

  class SonicPiSynth < SynthInfo
    def prefix
      "sonic-pi-"
    end
  end

  class DullBell < SonicPiSynth
    def name
      "Dull Bell"
    end

    def synth_name
      "dull_bell"
    end

    def doc
      "A simple dull dischordant bell sound."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1
      }
    end
  end

  class PrettyBell < DullBell
    def name
      "Pretty Bell"
    end

    def synth_name
      "pretty_bell"
    end

    def doc
      "A simple pretty bell sound."
    end
  end

  class Beep < SonicPiSynth
    def name
      "Sine Wave"
    end

    def synth_name
      "beep"
    end

    def doc
      "A simple pure sine wave."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.0,
        :decay => 0,
        :sustain => 0,
        :release => 0.3,
        :attack_level => 1,
        :sustain_level => 1
      }
    end
  end

  class Saw < Beep
    def name
      "Saw Wave"
    end

    def synth_name
      "saw"
    end

    def doc
      "A simple saw wave with a low pass filter."
    end
  end


  class SawS < Beep
    def name
      "Saw Wave Simple"
    end

    def synth_name
      "saw_s"
    end

    def doc
      "A simple saw wave"
    end
  end

  class Pulse < SonicPiSynth
    def name
      "Pulse Wave"
    end

    def synth_name
      "pulse"
    end

    def doc
      "A simple pulse wave with a low pass filter."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 0.3,
        :attack_level => 1,
        :sustain_level => 1,

        :cutoff => lambda{rrand(95, 105)},
        :cutoff_slide => 0,
        :pulse_width => 0.5,
        :pulse_width_slide => 0
      }
    end
  end

  class PulseS < SonicPiSynth
    def name
      "Pulse Wave Simple"
    end

    def synth_name
      "pulse_s"
    end

    def doc
      "A simple pulse wave."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 0.3,
        :attack_level => 1,
        :sustain_level => 1,

        :pulse_width => 0.5,
        :pulse_width_slide => 0
      }
    end
  end

  class Tri < Pulse
    def name
      "Triangle Wave"
    end

    def synth_name
      "tri"
    end

    def doc
      "A simple triangle wave with a low pass filter."
    end
  end

  class TriS < Beep
    def name
      "Triangle Wave Simple"
    end

    def synth_name
      "tri_s"
    end

    def doc
      "A simple triangle wave."
    end
  end

  class DSaw < SonicPiSynth
    def name
      "Detuned Saw wave"
    end

    def synth_name
      "dsaw"
    end

    def doc
      "A pair of detuned saw waves with a low pass filter."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.1,
        :decay => 0,
        :sustain => 0,
        :release => 0.3,
        :attack_level => 1,
        :sustain_level => 1,

        :cutoff => 100,
        :cutoff_slide => 0,
        :detune => 0.1,
        :detune_slide => 0
      }
    end
  end

  class DSawS < SonicPiSynth
    def name
      "Detuned Saw Wave Simple"
    end

    def synth_name
      "dsaw_s"
    end

    def doc
      "A pair of detuned saw waves."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.1,
        :decay => 0,
        :sustain => 0,
        :release => 0.3,
        :attack_level => 1,
        :sustain_level => 1,

        :detune => 0.1,
        :detune_slide => 0
      }
    end
  end

  class FM < SonicPiSynth
    def name
      "Basic FM synthesis"
    end

    def synth_name
      "fm"
    end

    def doc
      "A sine wave with a fundamental frequency which is modulated at audio rate by another sine wave with a specific modulation division and depth."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 1,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,

        :divisor => 2,
        :divisor_slide => 0,
        :depth => 1,
        :depth_slide => 0
      }
    end

    def specific_arg_info
      {
        :divisor =>
        {
          :doc => "Modifies the frequency of the modulator oscillator relative to the carrier. Don't worry too much about what this means - just try different numbers out!",
          :validations => [],
          :modulatable => true
        },

        :divisor_slide =>
        {
          :doc => generic_slide_doc(:divisor),
          :validations => [v_positive(:divisor_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :depth =>
        {
          :doc => "Modifies the depth of the carrier wave used to modify fundamental frequency. Don't worry too much about what this means - just try different numbers out!",
          :validations => [],
          :modulatable => true
        },

        :depth_slide =>
        {
          :doc => generic_slide_doc(:depth),
          :validations => [v_positive(:depth_slide)],
          :modulatable => true,
          :bpm_scale => true
        }
      }

    end
  end

  class ModFM < FM

    def name
      "Basic FM synthesis with frequency modulation"
    end

    def synth_name
      "mod_fm"
    end

    def arg_defaults
      super.merge({
                    :mod_phase => 1,
                    :mod_range => 5,
                    :mod_width => 0.5
                  })
    end


end

  class ModSaw < SonicPiSynth
    def name
      "Modulated Saw Wave"
    end

    def synth_name
      "mod_saw"
    end

    def doc
      "A saw wave which modulates between two separate notes."
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 2,
        :attack_level => 1,
        :sustain_level => 1,

        :cutoff => 100,
        :cutoff_slide => 0,
        :mod_phase => 1,
        :mod_phase_slide => 0,
        :mod_range => 5,
        :mod_range_slide => 0,
        :mod_width => 0.5,
        :mod_width_slide => 0,
        :mod_phase_offset => 0.5
      }
    end
  end

  class ModSawS < SonicPiSynth
    def name
      "Simple Modulated Saw Wave"
    end

    def synth_name
      "mod_saw_s"
    end

    def doc
      ""
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 2,
        :attack_level => 1,
        :sustain_level => 1,

        :mod_phase => 1,
        :mod_phase_slide => 0,
        :mod_range => 5,
        :mod_range_slide => 0,
        :mod_width => 0.5,
        :mod_width_slide => 0,
        :mod_phase_offset => 0.5
      }
    end
  end

  class ModDSaw < SonicPiSynth
    def name
      "Modulated Detuned Saw Waves"
    end

    def synth_name
      "mod_dsaw"
    end

    def doc
      ""
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 2,
        :attack_level => 1,
        :sustain_level => 1,

        :cutoff => 100,
        :cutoff_slide => 0,
        :mod_phase => 1,

        :mod_phase_slide => 0,
        :mod_range => 5,
        :mod_range_slide => 0,
        :mod_width => 0.5,
        :mod_width_slide => 0,
        :mod_phase_offset => 0.5,
        :detune => 0.1,
        :detune_slide => 0
      }
    end
  end

  class ModDSawS < SonicPiSynth
    def name
      "Modulated Detuned Saw Waves Simple"
    end

    def synth_name
      "mod_dsaw_s"
    end

    def doc
      ""
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 2,
        :attack_level => 1,
        :sustain_level => 1,

        :mod_phase => 1,
        :mod_phase_slide => 0,
        :mod_range => 5,
        :mod_range_slide => 0,
        :mod_width => 0.5,
        :mod_width_slide => 0,
        :mod_phase_offset => 0.5,
        :detune => 0.1,
        :detune_slide => 0
      }
    end
  end

  class ModSine < SonicPiSynth
    def name
      "Modulated Sine Wave"
    end

    def synth_name
      "mod_sine"
    end

    def doc
      ""
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 2,
        :attack_level => 1,
        :sustain_level => 1,

        :cutoff => 100,
        :cutoff_slide => 0,
        :mod_phase => 1,
        :mod_phase_slide => 0,
        :mod_range => 5,
        :mod_range_slide => 0,
        :mod_width => 0.5,
        :mod_width_slide => 0,
        :mod_phase_offset => 0.5

      }
    end
  end

  class ModSineS < SonicPiSynth
    def name
      "Simple Modulated Sine Wave"
    end

    def synth_name
      "mod_sine_s"
    end

    def doc
      ""
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 2,
        :attack_level => 1,
        :sustain_level => 1,

        :mod_phase => 1,
        :mod_phase_slide => 0,
        :mod_range => 5,
        :mod_range_slide => 0,
        :mod_width => 0.5,
        :mod_width_slide => 0,
        :mod_phase_offset => 0.5
      }
    end
  end

  class ModTri < SonicPiSynth
    def name
      "Modulated Triangle Wave"
    end

    def synth_name
      "mod_tri"
    end

    def doc
      ""
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 2,
        :attack_level => 1,
        :sustain_level => 1,

        :cutoff => 100,
        :cutoff_slide => 0,
        :mod_phase => 1,
        :mod_phase_slide => 0,
        :mod_range => 5,
        :mod_range_slide => 0,
        :mod_width => 0.5,
        :mod_width_slide => 0,
        :mod_phase_offset => 0.5
      }
    end
  end

  class ModTriS < SonicPiSynth
    def name
      "Simple Modulated Triangle Wave"
    end

    def synth_name
      "mod_tri_s"
    end

    def doc
      ""
    end


    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 2,
        :attack_level => 1,
        :sustain_level => 1,

        :mod_phase => 1,
        :mod_phase_slide => 0,
        :mod_range => 5,
        :mod_range_slide => 0,
        :mod_width => 0.5,
        :mod_width_slide => 0,
        :mod_phase_offset => 0.5
      }
    end
  end

  class ModPulse < SonicPiSynth
    def name
      "Modulated Pulse"
    end

    def synth_name
      "mod_pulse"
    end

    def doc
      ""
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 2,
        :attack_level => 1,
        :sustain_level => 1,

        :cutoff => 100,
        :cutoff_slide => 0,
        :mod_phase => 1,
        :mod_phase_slide => 0,
        :mod_range => 5,
        :mod_range_slide => 0,
        :mod_width => 0.5,
        :mod_width_slide => 0,
        :pulse_width => 0.5,
        :pulse_width_slide => 0
      }
    end
  end

  class ModPulseS < SonicPiSynth
    def name
      "Simple Modulated Pulse"
    end

    def synth_name
      "mod_pulse_s"
    end

    def doc
      ""
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 2,
        :attack_level => 1,
        :sustain_level => 1,

        :mod_phase => 1,
        :mod_phase_slide => 0,
        :mod_range => 5,
        :mod_range_slide => 0,
        :mod_width => 0.5,
        :mod_width_slide => 0,
        :pulse_width => 0.5,
        :pulse_width_slide => 0
      }
    end
  end

  class TB303 < SonicPiSynth
    def name
      "TB-303 Emulation"
    end

    def synth_name
      "tb303"
    end

    def doc
      ""
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 2,
        :attack_level => 1,
        :sustain_level => 1,

        :cutoff => 80,
        :cutoff_slide => 0,
        :cutoff_min => 30,
        :res => 0.1,
        :res_slide => 0,
        :wave => 0,
        :pulse_width => 0.5,
        :pulse_width_slide => 0
      }
    end

    def specific_arg_info
      {

        :cutoff =>
        {
          :doc => "",
          :validations => [v_positive(:cutoff), v_less_than(:cutoff, 130)],
          :modulatable => true
        },

        :cutoff_min =>
        {
          :doc => "",
          :validations => [v_positive(:cutoff), v_less_than(:cutoff, 130)],
          :modulatable => true
        },

        :wave =>
        {
          :doc => "Wave type - 0 saw, 1 pulse",
          :validations => [v_one_of(:wave, [0, 1])],
          :modulatable => true
        },

        :pulse_width =>
        {
          :doc => "Only valid if wave is type pulse.",
          :validations => [v_positive(:pulse_width)],
          :modulatable => true
        },

        :pulse_width_slide =>
        {
          :doc => "Time in seconds for pulse width to change. Only valid if wave is type pulse.",
          :validations => [v_positive(:pulse_width_slide)],
          :modulatable => true,
          :bpm_scale => true
        }

      }
    end
  end

  class Supersaw < SonicPiSynth
    def name
      "Supersaw"
    end

    def synth_name
      "supersaw"
    end

    def doc
      ""
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 2,
        :attack_level => 1,
        :sustain_level => 1,

        :cutoff => 130,
        :cutoff_slide => 0,
        :res => 0.3,
        :res_slide => 0

      }
    end
  end

  class SupersawS < SonicPiSynth
    def name
      "Supersaw Simple"
    end

    def synth_name
      "supersaw_s"
    end

    def doc
      ""
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 2,
        :attack_level => 1,
        :sustain_level => 1
      }
    end

  end

  class Zawa < SonicPiSynth
    def name
      "Zawa"
    end

    def synth_name
      "zawa"
    end

    def doc
      "Write me"
    end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.1,
        :decay => 0,
        :sustain => 0,
        :release => 1,
        :attack_level => 1,
        :sustain_level => 1,

        :cutoff => 100,
        :cutoff_slide => 0,
        :phase => 1,
        :phase_slide => 0,
        :depth => 1.5,
        :depth_slide => 0

      }

    end
  end


  class Prophet < SonicPiSynth
    def name
      "The Prophet"
    end

    def synth_name
      "prophet"
    end

    def doc
      "Dark and swirly, this synth uses Pulse Width Modulation (PWM) to create a timbre which continually moves around. This effect is created using the pulse ugen which produces a variable width square wave. We then control the width of the pulses using a variety of LFOs - sin-osc and lf-tri in this case. We use a number of these LFO modulated pulse ugens with varying LFO type and rate (and phase in some cases to provide the LFO with a different starting point. We then mix all these pulses together to create a thick sound and then feed it through a resonant low pass filter (rlpf). For extra bass, one of the pulses is an octave lower (half the frequency) and its LFO has a little bit of randomisation thrown into its frequency component for that extra bit of variety."
end

    def arg_defaults
      {
        :note => 52,
        :note_slide => 0,
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0.01,
        :decay => 0,
        :sustain => 0,
        :release => 2,
        :attack_level => 1,
        :sustain_level => 1,

        :cutoff => 110,
        :cutoff_slide => 0,
        :res => 0.3,
        :res_slide => 0
      }
    end

  end

  class StudioInfo < SonicPiSynth

  end

  class BasicMonoPlayer < StudioInfo
    def name
      "Basic Mono Sample Player (no env)"
    end

    def synth_name
      "basic_mono_player"
    end

    def doc
      ""
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,
        :rate => 1,
        :rate_slide => 0
      }
    end
  end

  class BasicStereoPlayer < BasicMonoPlayer
    def name
      "Basic Stereo Sample Player (no env)"
    end

    def synth_name
      "basic_stereo_player"
    end

    def doc
      ""
    end
  end

  class MonoPlayer < StudioInfo
    def name
      "Mono Sample Player"
    end

    def synth_name
      "mono_player"
    end

    def doc
      ""
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :pan => 0,
        :pan_slide => 0,

        :attack => 0,
        :sustain => -1,
        :release => 0,

        :rate => 1,
        :start => 0,
        :finish => 1
      }
    end

    def specific_arg_info
      {

        :attack =>
        {
          :doc => "",
          :validations => [v_positive(:attack)],
          :modulatable => false
        },

        :sustain =>
        {
          :doc => "",
          :validations => [v_positive(:attack)],
          :modulatable => false
        },

        :release =>
        {
          :doc => "",
          :validations => [[lambda{|args| v = args[:release] ; (v == -1) || (v >= 0)}, "must either be a positive value or -1"]],
          :modulatable => false
        },

        :rate =>
        {
          :doc => "",
          :validations => [],
          :modulatable => false
        },

        :start =>
        {
          :doc => "",
          :validations => [v_positive(:start), v_between_inclusive(:start, 0, 1)],
          :modulatable => false
        },

        :finish =>
        {
          :doc => "",
          :validations => [v_positive(:finish), v_between_inclusive(:finish, 0, 1)],
          :modulatable => false
        },

      }
    end

  end

  class StereoPlayer < MonoPlayer
    def name
      "Stereo Sample Player"
    end

    def synth_name
      "stereo_player"
    end
  end

  class BaseMixer < StudioInfo

  end

  class BasicMixer < BaseMixer
    def name
      "Basic Mixer"
    end

    def synth_name
      "basic_mixer"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0.2
      }
    end

  end

  class FXInfo < BaseInfo
    def prefix
      "sonic-pi-"
    end
  end

  class FXReverb < FXInfo
    def name
      "Reverb"
    end

    def synth_name
      "fx_reverb"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :mix => 0.4,
        :mix_slide => 0,

        :room => 0.6,
        :room_slide => 0,
        :damp => 0.5,
        :damp_slide => 0
      }
    end
  end

  class FXBitcrusher < FXInfo
    def name
      "Bitcrusher"
    end

    def synth_name
      "fx_bitcrusher"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :mix => 1,
        :mix_slide => 0,
        :sample_rate => 10000,
        :sample_rate_slide => 0,
        :bits => 8,
        :bits_slide => 0
      }
    end

    def specific_arg_info
      {
        :sample_rate =>
        {
          :doc => "The sample rate the audio will be resampled at.",
          :validations => [v_positive_not_zero(:sample_rate)],
          :modulatable => true
        },

        :bits =>
        {
          :doc => "The bit depth of the resampled audio.",
          :validations => [v_positive_not_zero(:bits)],
          :modulatable => true
        }
      }
    end

  end

  class FXLevel < FXInfo
    def name
      "Level Amplifier"
    end

    def synth_name
      "fx_level"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0
      }
    end
  end

  class FXEcho < FXInfo
    def name
      "Echo"
    end

    def synth_name
      "fx_echo"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :mix => 1,
        :mix_slide => 0,
        :phase => 0.25,
        :phase_slide => 0,
        :decay => 8,
        :decay_slide => 0,
        :max_phase => 2,
        :amp => 1,
        :amp_slide => 0
      }
    end

    def specific_arg_info
      {
        :max_phase =>
        {
          :doc => "The maximum phase duration in seconds.",
          :validations => [v_positive_not_zero(:max_phase)],
          :modulatable => false
        },

        :phase =>
        {
          :doc => "The time between echoes in seconds.",
          :validations => [v_positive_not_zero(:phase)],
          :modulatable => true,
          :bpm_scale => true

        },

        :phase_slide =>
        {
          :doc => "Slide time in seconds between phase values",
          :validations => [v_positive(:phase_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :decay =>
        {
          :doc => "The time it takes for the echoes to fade away in seconds.",
          :validations => [v_positive_not_zero(:decay)],
          :modulatable => true,
          :bpm_scale => true
        },

        :decay_slide =>
        {
          :doc => "Slide time in seconds between decay times",
          :validations => [v_positive(:decay_slide)],
          :modulatable => true,
          :bpm_scale => true
        }
      }
    end

    def kill_delay(args_h)
      args_h[:decay] || arg_defaults[:decay]
    end

  end

  class FXSlicer < FXInfo
    def name
      "Slicer"
    end

    def synth_name
      "fx_slicer"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :mix => 1,
        :mix_slide => 0,
        :phase => 0.25,
        :phase_slide => 0,
        :width => 0.5,
        :width_slide => 0,
        :phase_offset => 0,
        :amp => 1,
        :amp_slide => 0.05
      }
    end

    def specific_arg_info
      {
        :phase =>
        {
          :doc => "The phase duration (in seconds) of the slices",
          :validations => [v_positive_not_zero(:phase)],
          :modulatable => true,
          :bpm_scale => true
        },

        :phase_slide =>
        {
          :doc => "Slide time in seconds between phase values",
          :validations => [v_positive(:phase_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :width =>
        {
          :doc => "The width of the slices - 0 - 1.",
          :validations => [v_between_exclusive(:width, 0, 1)],
          :modulatable => true
        },

        :width_slide =>
        {
          :doc => "Slide time in seconds between width values",
          :validations => [v_positive(:width_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :phase_offset=>
        {
          :doc => "Initial phase offset.",
          :validations => [v_between_inclusive(:phase_offset, 0, 1)],
          :modulatable => false
        },

        :amp_slide =>
        {
          :doc => "The slide lag time for amplitude changes.",
          :validations => [v_positive(:amp_slide)],
          :modulatable => true,
          :bpm_scale => true
        },

        :amp =>
        {
          :doc => "The amplitude of the resulting effect.",
          :validations => [v_positive(:amp)],
          :modulatable => true
        }
      }
    end
  end


  class FXIXITechno < FXInfo
    def name
      "Techno from IXI Lang"
    end

    def synth_name
      "fx_ixi_techno"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :mix => 1,
        :mix_slide => 0,
        :phase => 4,
        :phase_slide => 0,
        :cutoff_min => 60,
        :cutoff_min_slide => 0,
        :cutoff_max => 120,
        :cutoff_max_slide => 0,
        :res => 0.2,
        :res_slide => 0
      }
    end

    def specific_arg_info
      {
        :phase =>
        {
          :doc => "The phase duration (in seconds) for filter modulation cycles",
          :validations => [v_positive_not_zero(:phase)],
          :modulatable => true,
          :bpm_scale => true
        }

      }
    end
  end


  class FXCompressor < FXInfo
    def name
      "Compressor"
    end

    def synth_name
      "fx_compressor"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :mix => 1,
        :mix_slide => 0,
        :pre_amp => 1,
        :pre_amp_slide => 0,
        :threshold => 0.2,
        :threshold_slide => 0,
        :clamp_time => 0.01,
        :clamp_time_slide => 0,
        :slope_above => 0.5,
        :slope_above_slide => 0,
        :slope_below => 1,
        :slope_below_slide => 0,
        :relax_time => 0.01,
        :relax_time_slide => 0
      }
    end

    def specific_arg_info
      {
        :pre_amp =>
        {
          :doc => "Amplication applied to the signal before it is compressed.",
          :validations => [v_positive(:pre_amp)],
          :modulatable => true
        },

        :pre_amp_slide =>
        {
          :doc => "Slide time in seconds between pre_amp values",
          :validations => [v_positive(:pre_amp_slide)],
          :modulatable => true,
          :bpm_scale => true
        }
      }
    end
  end


  class FXRLPF < FXInfo
    def name
      "Resonant Low Pass Filter"
    end

    def synth_name
      "fx_rlpf"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :mix => 1,
        :mix_slide => 0,
        :cutoff => 100,
        :cutoff_slide => 0,
        :res => 0.5,
        :res_slide => 0
      }
    end

    def specific_arg_info
      {


      }
    end
  end

  class FXNormRLPF < FXRLPF
    def name
      "Normalised Resonant Low Pass Filter"
    end

    def synth_name
      "fx_norm_rlpf"
    end
  end

  class FXRHPF < FXInfo
    def name
      "Resonant High Pass Filter"
    end

    def synth_name
      "fx_rhpf"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :mix => 1,
        :mix_slide => 0,
        :cutoff => 100,
        :cutoff_slide => 0,
        :res => 0.5,
        :res_slide => 0
      }
    end

    def specific_arg_info
      {


      }
    end
  end

  class FXNormRHPF < FXRLPF
    def name
      "Normalised Resonant High Pass Filter"
    end

    def synth_name
      "fx_norm_rhpf"
    end
  end

  class FXLPF < FXInfo
    def name
      "Low Pass Filter"
    end

    def synth_name
      "fx_lpf"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :mix => 1,
        :mix_slide => 0,
        :cutoff => 100,
        :cutoff_slide => 0
      }
    end

    def specific_arg_info
      {


      }
    end
  end

  class FXNormLPF < FXLPF
    def name
      "Normalised Low Pass Filter"
    end

    def synth_name
      "fx_norm_lpf"
    end
  end

  class FXHPF < FXInfo
    def name
      "High Pass Filter"
    end

    def synth_name
      "fx_hpf"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :mix => 1,
        :mix_slide => 0,
        :cutoff => 100,
        :cutoff_slide => 0
      }
    end

    def specific_arg_info
      {


      }
    end
  end

  class FXNormHPF < FXRLPF
    def name
      "Normalised High Pass Filter"
    end

    def synth_name
      "fx_norm_hpf"
    end
  end

  class FXNormaliser < FXInfo
    def name
      "Normaliser"
    end

    def synth_name
      "fx_normaliser"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :mix => 1,
        :mix_slide => 0,
        :amp => 1,
        :amp_slide => 0
      }
    end
  end

  class FXDistortion < FXInfo
    def name
      "Distortion"
    end

    def synth_name
      "fx_distortion"
    end

    def arg_defaults
      {
        :amp => 1,
        :amp_slide => 0,
        :mix => 1,
        :mix_slide => 0,
        :distort => 0.5,
        :distort_slide => 0
      }
    end
  end



  class BaseInfo

    @@grouped_samples =
      {
      :drum => {
        :desc => "Drum Sounds",
        :prefix => "drum_",
        :samples => [
          :drum_heavy_kick,
          :drum_tom_mid_soft,
          :drum_tom_mid_hard,
          :drum_tom_lo_soft,
          :drum_tom_lo_hard,
          :drum_tom_hi_soft,
          :drum_tom_hi_hard,
          :drum_splash_soft,
          :drum_splash_hard,
          :drum_snare_soft,
          :drum_snare_hard,
          :drum_cymbal_soft,
          :drum_cymbal_hard,
          :drum_cymbal_open,
          :drum_cymbal_closed,
          :drum_cymbal_pedal,
          :drum_bass_soft,
          :drum_bass_hard]},

      :elec => {
        :desc => "Electric Sounds",
        :prefix => "elec_",
        :samples => [
          :elec_triangle,
          :elec_snare,
          :elec_lo_snare,
          :elec_hi_snare,
          :elec_mid_snare,
          :elec_cymbal,
          :elec_soft_kick,
          :elec_filt_snare,
          :elec_fuzz_tom,
          :elec_chime,
          :elec_bong,
          :elec_twang,
          :elec_wood,
          :elec_pop,
          :elec_beep,
          :elec_blip,
          :elec_blip2,
          :elec_ping,
          :elec_bell,
          :elec_flip,
          :elec_tick,
          :elec_hollow_kick,
          :elec_twip,
          :elec_plip,
          :elec_blup]},

      :guit => {
        :desc => "Sounds featuring guitars",
        :prefix => "guit_",
        :samples => [
          :guit_harmonics,
          :guit_e_fifths,
          :guit_e_slide]},

      :misc => {
        :desc => "Miscellaneous Sounds",
        :prefix => "misc_",
        :samples => [
          :misc_burp]},

      :perc => {
        :desc => "Percussive Sounds",
        :prefix => "perc_",
        :samples => [
          :perc_bell]},

      :ambi => {
        :desc => "Ambient Sounds",
        :prefix => "ambi_",
        :samples => [
          :ambi_soft_buzz,
          :ambi_swoosh,
          :ambi_drone,
          :ambi_glass_hum,
          :ambi_glass_rub,
          :ambi_haunted_hum,
          :ambi_piano,
          :ambi_lunar_land,
          :ambi_dark_woosh,
          :ambi_choir]},

      :bass => {
        :desc => "Bass Sounds",
        :prefix => "bass_",
        :samples => [
          :bass_hit_c,
          :bass_hard_c,
          :bass_thick_c,
          :bass_drop_c,
          :bass_woodsy_c,
          :bass_voxy_c,
          :bass_voxy_hit_c,
          :bass_dnb_f]},

      :loop => {
        :desc => "Sounds for Looping",
        :prefix => "loop_",
        :samples => [
          :loop_industrial,
          :loop_compus,
          :loop_amen,
          :loop_amen_full]}}

    @@all_samples = (@@grouped_samples.values.reduce([]) {|s, el| s << el[:samples]}).flatten

    @@synth_infos =
      {
      :dull_bell => DullBell.new,
      :pretty_bell => PrettyBell.new,
      :beep => Beep.new,
      :saw => Saw.new,
      :saw_s => SawS.new,
      :pulse => Pulse.new,
      :pulse_s => PulseS.new,
      :tri => Tri.new,
      :tri_s => TriS.new,
      :dsaw => DSaw.new,
      :dsaw_s => DSawS.new,
      :fm => FM.new,
      :mod_fm => ModFM.new,
      :mod_saw => ModSaw.new,
      :mod_saw_s => ModSawS.new,
      :mod_dsaw => ModDSaw.new,
      :mod_dsaw_s => ModDSawS.new,
      :mod_sine => ModSine.new,
      :mod_sine_s => ModSineS.new,
      :mod_tri => ModTri.new,
      :mod_tri_s => ModTriS.new,
      :mod_pulse => ModPulse.new,
      :mod_pulse_s => ModPulseS.new,
      :tb303 => TB303.new,
      :supersaw => Supersaw.new,
      :supersaw_s => SupersawS.new,
      :prophet => Prophet.new,
      :zawa => Zawa.new,
      :mono_player => MonoPlayer.new,
      :stereo_player => StereoPlayer.new,

      :basic_mono_player => BasicMonoPlayer.new,
      :basic_stereo_player => BasicStereoPlayer.new,
      :basic_mixer => BasicMixer.new,

      :fx_bitcrusher => FXBitcrusher.new,
      :fx_reverb => FXReverb.new,
      :fx_replace_reverb => FXReverb.new,
      :fx_level => FXLevel.new,
      :fx_replace_level => FXLevel.new,
      :fx_echo => FXEcho.new,
      :fx_replace_echo => FXEcho.new,
      :fx_slicer => FXSlicer.new,
      :fx_replace_slicer => FXSlicer.new,
      :fx_ixi_techno => FXIXITechno.new,
      :fx_replace_ixi_techno => FXIXITechno.new,
      :fx_compressor => FXCompressor.new,
      :fx_replace_compressor => FXCompressor.new,
      :fx_rlpf => FXRLPF.new,
      :fx_replace_rlpf => FXRLPF.new,
      :fx_norm_rlpf => FXNormRLPF.new,
      :fx_replace_norm_rlpf => FXNormRLPF.new,
      :fx_rhpf => FXRHPF.new,
      :fx_replace_rhpf => FXRHPF.new,
      :fx_norm_rhpf => FXNormRHPF.new,
      :fx_replace_norm_rhpf => FXNormRHPF.new,
      :fx_hpf => FXHPF.new,
      :fx_replace_hpf => FXHPF.new,
      :fx_norm_hpf => FXNormHPF.new,
      :fx_replace_norm_hpf => FXNormHPF.new,
      :fx_lpf => FXLPF.new,
      :fx_replace_lpf => FXLPF.new,
      :fx_norm_lpf => FXNormLPF.new,
      :fx_replace_norm_lpf => FXNormLPF.new,
      :fx_normaliser => FXNormaliser.new,
      :fx_replace_normaliser => FXNormaliser.new,
      :fx_distortion => FXDistortion.new,
      :fx_replace_distortion => FXDistortion.new


      }

    def self.get_info(synth_name)
      @@synth_infos[synth_name.to_sym]
    end

    def self.get_all
      @@synth_infos
    end

    def self.grouped_samples
      @@grouped_samples
    end

    def self.all_samples
      @@all_samples
    end

    def self.info_doc_html_map(klass)
      key_mod = nil
      res = {}
      hv_face = "face=\"HelveticaNeue-Light,Helvetica Neue Light,Helvetica Neue\""

      max_len =  0
      get_all.each do |k, v|
        next unless v.is_a? klass
        next if (klass == FXInfo) && (k.to_s.include? 'replace_')
        next if v.is_a? StudioInfo
        if klass == SynthInfo
          max_len = k.to_s.size if k.to_s.size > max_len
        else
          max_len = (k.to_s.size - 3) if (k.to_s.size - 3) > max_len
        end
      end

      get_all.each do |k, v|
        next unless v.is_a? klass
        next if (klass == FXInfo) && (k.to_s.include? 'replace_')

        next if v.is_a? StudioInfo
        doc = ""
        doc << "<font size=\"7\", #{hv_face}>" << v.name << "</font>\n"
        if klass == SynthInfo
          safe_k = k
          doc << "<h2><font color=\"#3C3C3C\"><pre>use_synth"
          doc << " <font color=\"DeepPink\">:#{safe_k}</font></pre></h2>\n"

        else
          safe_k = k.to_s[3..-1]
          doc << "<h2><pre><font color=\"#3C3C3C\">with_fx"
          doc << " <font color=\"DeepPink\">:#{safe_k}</font> <font color=\"DarkOrange\">do</font><br/>  play <font color=\"DodgerBlue\">50</font><br/><font color=\"DarkOrange\">end</font></pre></font></h2>\n"
        end

        cnt = 0
        doc << "<table cellpadding=\"2\">\n <tr>"
        arglist = ""
        v.arg_info.each do |ak, av|
          arglist << "</tr><tr>" if cnt%6 == 0
          bg_colour = cnt.even? ? "#5e5e5e" : "#E8E8E8"
          fnt_colour = cnt.even? ? "white" : "#5e5e5e"
          cnt += 1
          arglist << "<td bgcolor=\"#{bg_colour}\">\n  <pre><h4><font color=\"#{fnt_colour}\">#{ak}: </font></h4</pre>\n</td>\n<td bgcolor=\"#{bg_colour}\">\n  <pre><h4><font color=\"#{fnt_colour}\">#{av[:default]}</font></h4></pre>\n</td>\n"
        end
        arglist << "</tr></table>\n"
        doc << arglist


        doc << "<p><font size=\"5\", #{hv_face}>"
        doc << "  " << v.doc << "</font></p>\n"

        doc << "<table cellpadding=\"10\">\n"
        doc << "<tr><th></th><th></th></tr>\n"

        cnt = 0
        v.arg_info.each do |ak, av|
          cnt += 1
          background_colour = cnt.even? ? "#F8F8F8" : "#E8E8E8"
          key_bg_colour = cnt.even? ? "#FFF0F5" : "#FFE4E1"
          doc << "  <tr bgcolor=\"#{background_colour}\">\n"
          doc << "    <td bgcolor=\"#{key_bg_colour}\"><h3><pre> #{ak}:</pre></h3></td>\n"
          doc << "      <td>\n"
          doc << "        <font size=\"4\", #{hv_face}>\n"
          doc << "          #{av[:doc] || 'write me'}<br/></font>\n"
          doc << "          <font size=\"3\", #{hv_face}>Default: #{av[:default]}<br/>\n"
          doc << "          #{av[:constraints].join(",")}<br/>\n" unless av[:constraints].empty?
          doc << "          #{av[:modulatable] ? "May be changed whilst playing" : "Can not be changed once set"}\n"
          doc << "       </font>\n"
          doc << "     </td>\n"
          doc << " </tr>\n"
        end
        doc << "  </table>\n"
        res["#{safe_k}"] = doc
      end
      res
    end

    def self.info_doc_markdown(name, klass, key_mod=nil)
      res = "# #{name}\n\n"

      get_all.each do |k, v|
        next unless v.is_a? klass
        snake_case = v.name.downcase.gsub(/ /, "-")
        res << "* [#{v.name}](##{snake_case})\n"
      end
      res << "\n"
      get_all.each do |k, v|
        next unless v.is_a? klass
        res << "## " << v.name << "\n\n"
        res << "### Key:\n"
        mk = key_mod ? key_mod.call(k) : k
        res << "  :#{mk}\n\n"
        res << "### Doc:\n"
        res << "  " << v.doc << "\n\n"
        res << "### Arguments:" "\n"
        v.arg_info.each do |ak, av|
          res << "  * #{ak}:\n"
          res << "    - doc: #{av[:doc] || 'write me'}\n"
          res << "    - default: #{av[:default]}\n"
          res << "    - constraints: #{av[:constraints].empty? ? "none" : av[:constraints].join(",")}\n"
          res << "    - #{av[:modulatable] ? "May be changed whilst playing" : "Can not be changed once set"}\n\n"
        end
        res << "\n\n"

      end
      res
    end

    def self.synth_doc_html_map
      info_doc_html_map(SynthInfo)
    end

    def self.fx_doc_html_map
      info_doc_html_map(FXInfo)
    end

    def self.synth_doc_markdown
      info_doc_markdown("Synths", SynthInfo)
    end

    def self.fx_doc_markdown
      info_doc_markdown("FX", FXInfo, lambda{|k| k.to_s[3..-1]})
    end

    def self.samples_doc_html_map
      hv_face = "face=\"HelveticaNeue-Light,Helvetica Neue Light,Helvetica Neue\""
      res = {}

      grouped_samples.each do |k, v|
      cnt = 0
        cnt = 0
        html = ""
        html << "<font size=\"7\", #{hv_face}>" << v[:desc] << "</font>\n"
        html << "<table cellpadding=\"2\">\n <tr>"
        arglist = ""
        StereoPlayer.new.arg_info.each do |ak, av|
          arglist << "</tr><tr>" if cnt%6 == 0
          bg_colour = cnt.even? ? "#5e5e5e" : "#E8E8E8"
          fnt_colour = cnt.even? ? "white" : "#5e5e5e"
          cnt += 1
          arglist << "<td bgcolor=\"#{bg_colour}\">\n  <pre><h4><font color=\"#{fnt_colour}\">#{ak}: </font></h4</pre>\n</td>\n<td bgcolor=\"#{bg_colour}\">\n  <pre><h4><font color=\"#{fnt_colour}\">#{av[:default]}</font></h4></pre>\n</td>\n"
        end
        arglist << "</tr></table>\n"
        html << arglist

        html << "<table cellpadding=\"2\">\n <tr>"

        v[:samples].each do |s|
          html << "  <tr><td bgcolor=\"white\"><h2><pre><font color=\"#3C3C3C\"> sample</font> <font color=\"DeepPink\">:#{s}<font></pre></h2></td></tr>\n"
        end
        html << "</table>\n"
        doc = ""
        doc << "<table cellpadding=\"10\">\n"
        doc << "<tr><th></th><th></th></tr>\n"

        cnt = 0
        StereoPlayer.new.arg_info.each do |ak, av|
          cnt += 1
          background_colour = cnt.even? ? "#F8F8F8" : "#E8E8E8"
          key_bg_colour = cnt.even? ? "#FFF0F5" : "#FFE4E1"
          doc << "  <tr bgcolor=\"#{background_colour}\">\n"
          doc << "    <td bgcolor=\"#{key_bg_colour}\"><h3><pre> #{ak}:</pre></h3></td>\n"
          doc << "      <td>\n"
          doc << "        <font size=\"4\", #{hv_face}>\n"
          doc << "          #{av[:doc] || 'write me'}<br/></font>\n"
          doc << "          <font size=\"3\", #{hv_face}>Default: #{av[:default]}<br/>\n"
          doc << "          #{av[:constraints].join(",")}<br/>\n" unless av[:constraints].empty?
          doc << "          #{av[:modulatable] ? "May be changed whilst playing" : "Can not be changed once set"}\n"
          doc << "       </font>\n"
          doc << "     </td>\n"
          doc << " </tr>\n"
        end
        doc << "  </table>\n"
        html << doc
        res[v[:desc]] = html
      end
      res
    end

    def self.samples_doc_markdown
      res = "# Samples\n\n"
      grouped_samples.values.each do |info|
        res << "## #{info[:desc]}\n"
        info[:samples].each do |s|
          res << "* :#{s}\n"
        end
        res << "\n\n"

      end
      res
    end
  end
end
