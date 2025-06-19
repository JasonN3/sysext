# app
APPS := $(filter-out build,$(patsubst %/,%,$(sort $(dir $(wildcard */*)))))
# app.raw
IMAGES := $(foreach app,$(APPS),$(app).raw)
OS_IMAGE := ghcr.io/jasonn3/fedora_base
OS_VERSION := main
ARCH := $(shell uname -m)

.PHONY: all $(APPS) encrypt prereqs clean
.SECONDEXPANSION:

# Build all images
all: $(APPS)

# Build all images related to service
$(APPS): % : %.raw

# Build and encrypt images
encrypt: $(foreach image,$(IMAGES),encrypted/$(image))

# Write keyfile
keyfile:
	@echo Writing keyfile
	@echo -n '${ENCRYPT_KEY}' > keyfile

# Encrypt built image
encrypted/%: % keyfile
	$( eval $<_APP := $(patsubst %.raw,%,$<))
	@echo Encrypting $<
	[[ -d encrypted ]] || mkdir encrypted
	$(eval $<_SIZE := $(shell stat -c %s $<))
	# Disk size + LUKS (16Mib)
	fallocate -l $$(( $($<_SIZE) + 16777216)) $@
	sudo cryptsetup -q luksFormat $@ keyfile
	sudo cryptsetup -d keyfile open $@ $($<_APP)
	sudo dd if=$< of=/dev/mapper/$($<_APP) status=progress
	sudo cryptsetup close $($<_APP)

# Build the erofs image
%.raw: build/% $$(shell find % -type f)
	$(eval $@_APP := $(patsubst %.raw,%,$@))
	@echo "Making $@ with source build/$($@_APP)"
	if [[ -d $($@_APP)/rootfs/opt ]]; then rsync -rmlp $($@_APP)/rootfs/opt build/$($@_APP)/; fi
	if [[ -d $($@_APP)/rootfs/usr ]]; then rsync -rmlp $($@_APP)/rootfs/usr build/$($@_APP)/; fi
	if [[ -d $($@_APP)/rootfs/etc ]]; then rsync -rmlp $($@_APP)/rootfs/etc build/$($@_APP)/; fi
	mkfs.erofs -d3 $@ build/$($@_APP)

# Build system extension files
build/%: rsync-etc.exclude rsync-opt.exclude rsync-usr.exclude
	@echo Building $@ filesystem
	$(eval $(subs /,_,$@)_APP := $(patsubst build/%,%,$@))
	mkdir -p $@
	podman run --name make-$($(subs /,_,$@)_APP) $(OS_IMAGE):$(OS_VERSION) dnf install -y $$(cat $($(subs /,_,$@)_APP)/packages | tr '\n' ' ')
	ln -s $$(podman inspect make-$($(subs /,_,$@)_APP) | jq -r '.[].GraphDriver.Data.UpperDir') $@_upper
	if [[ -d $@_upper/opt ]]; then rsync -rmlp --exclude-from=rsync-opt.exclude $@_upper/opt $@/; fi
	if [[ -d $@_upper/usr ]]; then rsync -rmlp --exclude-from=rsync-usr.exclude $@_upper/usr $@/; fi
	if [[ -d $@_upper/etc ]]; then rsync -rmlp --exclude-from=rsync-etc.exclude $@_upper/etc $@/; fi
	podman rm make-$($(subs /,_,$@)_APP)
	rm $@_upper

# Install prerequisites
prereqs:
	apt install -y erofs-utils cryptsetup-bin jq

# Clean up generated files
clean:
	rm -f *.raw
	rm -Rf output
	rm -Rf encrypted
	rm -f keyfile
	rm -Rf build
	podman rm -i $(foreach app,$(APPS),make-$(app))
