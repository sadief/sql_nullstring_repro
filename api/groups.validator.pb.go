// Code generated by protoc-gen-gogo. DO NOT EDIT.
// source: groups.proto

package groups

import fmt "fmt"
import github_com_mwitkow_go_proto_validators "github.com/mwitkow/go-proto-validators"
import proto "github.com/gogo/protobuf/proto"
import math "math"
import _ "github.com/golang/protobuf/ptypes/timestamp"
import _ "github.com/mwitkow/go-proto-validators"

// Reference imports to suppress errors if they are not otherwise used.
var _ = proto.Marshal
var _ = fmt.Errorf
var _ = math.Inf

func (this *CreateGroupRequest) Validate() error {
	if oneOfNester, ok := this.GetParent().(*CreateGroupRequest_FirstId); ok {
		if oneOfNester.FirstId == "" {
			return github_com_mwitkow_go_proto_validators.FieldError("FirstId", fmt.Errorf(`value '%v' must not be an empty string`, oneOfNester.FirstId))
		}
	}
	if oneOfNester, ok := this.GetParent().(*CreateGroupRequest_SecondId); ok {
		if oneOfNester.SecondId == "" {
			return github_com_mwitkow_go_proto_validators.FieldError("SecondId", fmt.Errorf(`value '%v' must not be an empty string`, oneOfNester.SecondId))
		}
	}
	if oneOfNester, ok := this.GetParent().(*CreateGroupRequest_ThirdId); ok {
		if oneOfNester.ThirdId == "" {
			return github_com_mwitkow_go_proto_validators.FieldError("ThirdId", fmt.Errorf(`value '%v' must not be an empty string`, oneOfNester.ThirdId))
		}
	}
	return nil
}
func (this *Group) Validate() error {
	if this.CreatedAt != nil {
		if err := github_com_mwitkow_go_proto_validators.CallValidatorIfExists(this.CreatedAt); err != nil {
			return github_com_mwitkow_go_proto_validators.FieldError("CreatedAt", err)
		}
	}
	if this.UpdatedAt != nil {
		if err := github_com_mwitkow_go_proto_validators.CallValidatorIfExists(this.UpdatedAt); err != nil {
			return github_com_mwitkow_go_proto_validators.FieldError("UpdatedAt", err)
		}
	}
	return nil
}
