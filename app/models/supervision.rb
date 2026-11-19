# Links a technician to a supervisor who may sign their entries.
class Supervision < ApplicationRecord
  belongs_to :technician, class_name: "User"
  belongs_to :supervisor, class_name: "User"

  validates :supervisor_id, uniqueness: { scope: :technician_id }
  validate { errors.add(:supervisor, "can't be the technician") if technician_id == supervisor_id }
  validate { errors.add(:supervisor, "must be a supervisor") if supervisor && !supervisor.supervisor? }
end
