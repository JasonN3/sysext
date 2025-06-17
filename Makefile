DIRECTORIES := $(patsubst %/,%,$(sort $(dir $(wildcard */*))))
TYPES := conf sys service
IMAGES := $(foreach dir,$(foreach type,$(TYPES),$(subst /,_,$(wildcard $(DIRECTORIES)/$(type)))),$(dir).raw)

.PHONY: all $(DIRECTORIES) preqreqs clean
.SECONDEXPANSION:

# Build all images
all: $(DIRECTORIES)

# Build output directory for GitHub Actions
output: all
	mkdir output
	mv $(IMAGES) output/

# Build the erofs image
%.raw: $$(shell find $$(subst _,/,%))
	$(eval $@_SOURCE := $(subst _,/,$(subst .raw,,$@)))
	@echo "Making $@ with source $($@_SOURCE)"
	mkfs.erofs $@ $($@_SOURCE)

# Build all images related to service
$(DIRECTORIES): % : $(foreach type,$(TYPES),$(filter %_$(type).raw, $(IMAGES)))

# Install prerequisites
preqreqs:
	apt install -y erofs-utils

# Clean up generated files
clean:
	rm -f *.raw